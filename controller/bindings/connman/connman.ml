open Lwt
open Connman_interfaces
open Sexplib.Std
open Sexplib.Conv

let log_src = Logs.Src.create "connman"

let string_of_obus value =
  (* Helper to safely get string from OBus_value.V.single *)
  try
    Some OBus_value.C.(value |> cast_single basic_string)
  with
    _ -> None

let bool_of_obus value =
  (* Helper to safely get bool from OBus_value.V.single *)
  try
    Some OBus_value.C.(value |> cast_single basic_boolean)
  with
    _ -> None

let string_list_of_obus value =
   try
    OBus_value.C.(value |> cast_single (array basic_string))
   with
     _ -> []

module Technology =
struct
  type type' =
    | Wifi
    | Ethernet
    | Bluetooth
    | P2P
  [@@deriving sexp, yojson]

  let type_of_string = function
    | "wifi" -> Some Wifi
    | "ethernet" -> Some Ethernet
    | "bluetooth" -> Some Bluetooth
    | "p2p" -> Some P2P
    | _ -> None

  type t = {
    _proxy: (OBus_proxy.t [@sexp.opaque] [@yojson.opaque])
  ; name : string
  ; type' : type'
  ; powered : bool
  ; connected : bool
  } [@@deriving sexp, yojson]

  let set_property proxy ~name ~value =
    OBus_method.call
      Connman_interfaces.Net_connman_Technology.m_SetProperty proxy (name, value)

  let enable t =
    set_property t._proxy ~name:"Powered" ~value:(true |> OBus_value.C.(make_single basic_boolean))

  let disable t =
    set_property t._proxy ~name:"Powered" ~value:(false |> OBus_value.C.(make_single basic_boolean))

  let scan t =
    let%lwt () = Logs_lwt.debug ~src:log_src
        (fun m -> m "scanning %s" t.name)
    in
    OBus_method.call
      Connman_interfaces.Net_connman_Technology.m_Scan t._proxy ()

end

let register_agent proxy ~path =
  OBus_method.call
    Net_connman_Manager.m_RegisterAgent proxy path

let unregister_agent proxy ~path =
  OBus_method.call
    Net_connman_Manager.m_UnregisterAgent proxy path

module Agent =
struct

  type input =
    | None
    | Passphrase of string
  [@@deriving sexp, yojson]

  type t = input OBus_object.t

  type manager_error =
      | InvalidKey
      | ConnectFailed
      | Blocked
      (* see manager_error_of_string
      | OutOfRange
      | PinMissing
      | DhcpFailed
      | LoginFailed
      | AuthFailed
      *)
      | Unknown of string

  type agent_error =
      | PassMissing
      | MissingRequestedInputs of string list
      | BrowserRequested
      | UnexpectedFailure of exn

  type reported_error =
      | ManagerError of manager_error
      | AgentError of agent_error

  let request_input input service (fields: (string * OBus_value.V.single) list) =
    let%lwt () = Logs_lwt.debug ~src:log_src
        (fun m -> m "input requested from agent for service %s"
            (String.concat "/" service)
        )
    in
    let pass_requested = List.assoc_opt "Passphrase" fields in
    match (input, pass_requested) with
        | (Passphrase p, Some _) ->
            (* TODO: in theory manager can request passphrase _and_ other
               fields, so this case is kind of incomplete? *)
            return @@ Ok [ "Passphrase", p |> OBus_value.C.(make_single basic_string)]
        | (None, Some _) ->
          let%lwt () = Logs_lwt.err ~src:log_src (fun m -> m
            "Passphrase requested from agent, but not available.")
          in
          return @@ Error PassMissing
        | (_, None) ->
            (* This case is triggered when manager is requesting
               _some_ input(s) (so NOT open networks) and those inputs do not
               involve a passphrase.
            *)
            let (expected_properties, _) = List.split fields in
            let expected_properties_str =
                String.concat ", " expected_properties
            in
            let%lwt () = Logs_lwt.err ~src:log_src (fun m -> m
               "Manager is requesting additional missing input(s): %s"
               expected_properties_str
            )
            in
            return @@ Error (MissingRequestedInputs expected_properties)

  let request_browser input service url =
    let%lwt () = Logs_lwt.err ~src:log_src
        (fun m -> m "agent requested to open browser to url: %s" url)
    in
    return @@ Error BrowserRequested

  (* based on `connman_service_error` enum and it's stringified mapping in
    error2string: https://git.kernel.org/pub/scm/network/connman/connman.git/tree/src/service.c?h=1.42#n324 *)
  let manager_error_of_string = function
    | "invalid-key" -> InvalidKey
    | "connect-failed" -> ConnectFailed
    (* although this sounds generic, `blocked` err is only produced by connman
       when wpa_supplicant reports a wifi deauth with reason code = 6, which is
       "Class 2 frame received from nonauthenticated station".
       This seems like a protocol error? *)
    | "blocked" -> Blocked
(*
    (* defined, but never produced in connman v1.42 *)
    | "dhcp-failed" -> DhcpFailed
    | "out-of-range" -> OutOfRange
    | "pin-missing" -> PinMissing

    (* these are VPN related *)
    | "login-failed" -> LoginFailed
    | "auth-failed" -> AuthFailed
*)
    | s -> Unknown s

  let agent_error_msg = function
      | PassMissing ->
          "Passphrase is required for this access point"
      | MissingRequestedInputs props ->
          Printf.sprintf
            "Unsupported protocol: additional inputs are needed: %s"
            (String.concat ", " props)
      | BrowserRequested ->
          "Unsupported protocol: access point requires browser-based authentication"
      | UnexpectedFailure exn ->
          Printf.sprintf "Unexpected connection failure: %s" (Printexc.to_string exn)

  let interface on_error =
    let wrap_req f = fun obj (x1, x2) ->
        let%lwt caught_f = Lwt_result.catch
            (fun () -> f (OBus_object.get obj) x1 x2) |>
            (Lwt_result.map_error (fun e -> UnexpectedFailure e))
        in
        match (Result.join caught_f) with
            | Ok a -> Lwt.return a
            | Error err ->
                let%lwt () = on_error (AgentError err) in
                let obus_exn = OBus_error.make
                    "net.connman.Agent.Error.Canceled"
                    (agent_error_msg err)
                in
                Lwt.fail obus_exn
    in
    Connman_interfaces.Net_connman_Agent.make {
      m_ReportError = (
        fun obj (service, msg) ->
          let%lwt () = Logs_lwt.err ~src:log_src
              (fun m -> m "error reported to agent: %s" msg)
          in
          on_error (ManagerError (manager_error_of_string msg))
      );
      m_RequestInput = wrap_req request_input;
      m_RequestBrowser = wrap_req request_browser;
      m_Cancel = (fun obj () -> return_unit);
      m_Release = (fun obj () -> return_unit);
    }

  let create ~(input:input) on_error =
    let%lwt system_bus = OBus_bus.system () in
    let path = [ "net"; "connman"; "agent"
               ; Random.int 9999 |> string_of_int ]
    in
    let%lwt () = Logs_lwt.debug ~src:log_src
        (fun m -> m "creating connman agent at %s" (String.concat "/" path))
    in
    let obj = OBus_object.make ~interfaces:[interface on_error] path in
    let () = OBus_object.attach obj input in
    let () = OBus_object.export system_bus obj in
    return (path, obj)

  let destroy (agent:t) =
    let%lwt () = Logs_lwt.debug ~src:log_src
        (fun m -> m "detroying agent")
    in
    OBus_object.destroy agent
    |> return

end

module Service =
struct
  type state =
    | Idle
    | Failure
    | Association
    | Configuration
    | Ready
    | Disconnect
    | Online
  [@@deriving sexp, yojson]

  type security =
    | None
    | WEP
    | PSK
    | IEEE8021x
    | WPS
  [@@deriving sexp, yojson]

  let supported_security_protocols = [ None; WEP; PSK; ]

  let string_of_security s = sexp_of_security s |> Sexplib.Sexp.to_string

  module IPv4 =
  struct
    type t = {
      method' : string
    ; address : string
    ; netmask : string
    ; gateway : string option
    }
    [@@deriving sexp, yojson]

    let of_obus v =
      (fun () ->
         let open OBus_value.C in
         let properties = v |> cast_single (dict string variant) in
         { method' = properties |> List.assoc "Method" |> cast_single basic_string
         ; address = properties |> List.assoc "Address" |> cast_single basic_string
         ; netmask = properties |> List.assoc "Netmask" |> cast_single basic_string
         ; gateway = properties |> List.assoc_opt "Gateway" |> Option.map (cast_single basic_string)
         }
      )
      |> CCResult.guard
      |> CCResult.to_opt
  end

  module IPv6 =
  struct
    type t = {
      method' : string
    ; address : string
    ; prefix_length: int
    ; gateway : string option
    ; privacy : string
    }
    [@@deriving sexp, yojson]

    let of_obus v =
      (fun () ->
         let open OBus_value.C in
         let properties = v |> cast_single (dict string variant) in
         { method' = properties |> List.assoc "Method" |> cast_single basic_string
         ; address = properties |> List.assoc "Address" |> cast_single basic_string
         ; prefix_length = properties
                           |> List.assoc "PrefixLength"
                           |> cast_single basic_byte
                           |> int_of_char
         ; gateway = properties |> List.assoc_opt "Gateway" |> Option.map (cast_single basic_string)
         ; privacy = properties |> List.assoc "Privacy" |> cast_single basic_string
         }
      )
      |> CCResult.guard
      |> CCResult.to_opt
  end

  module Ethernet =
  struct
    type t = {
      method' : string
    ; interface : string
    ; address : string
    ; mtu : int
    }
    [@@deriving sexp, yojson]

    let of_obus v =
      (fun () ->
         let open OBus_value.C in
         let properties = v |> cast_single (dict string variant) in
         { method' = properties |> List.assoc "Method" |> cast_single basic_string
         ; interface = properties |> List.assoc "Interface" |> cast_single basic_string
         ; address = properties |> List.assoc "Address" |> cast_single basic_string
         ; mtu = properties |> List.assoc "MTU" |> cast_single basic_uint16
         }
      )
      |> CCResult.guard
      |> CCResult.to_opt
  end

  module Proxy =
  struct
    type credentials =
      { user: string
      ; password: (string [@sexp.opaque] [@yojson.opaque])
      }
      [@@deriving sexp, yojson]

    type t =
    { host: string
    ; port: int
    ; credentials: credentials option
    }
    [@@deriving sexp, yojson]

    let make ?user ?password host port =
      { host = host
      ; port = port
      ; credentials =
        (match user, password with
        | Some "", _ -> None
        | Some u, Some p -> Some { user = u; password = p }
        | _ -> None)
      }

    let validate str =
      let uri = Uri.of_string str in
      if Uri.path uri = ""
        && Uri.query uri = []
        && Uri.fragment uri = None
      then
        match Uri.scheme uri, Uri.host uri, Uri.port uri with
        | Some "http", Some host, Some port ->
          Some
            { credentials =
              (match Uri.user uri, Uri.password uri with
              | Some user, Some password -> Some { user = Uri.pct_decode user; password = Uri.pct_decode password }
              | _ -> None)
            ; host
            ; port
            }
        | _ -> None
      else
        None

    let to_uri ~include_userinfo t =
      let escape_userinfo = Uri.pct_encode ~component:`Userinfo in
      let
        userinfo =
          Option.map
            (fun credentials -> escape_userinfo credentials.user ^ ":" ^ escape_userinfo credentials.password)
            t.credentials
      in
      Uri.empty
      |> Fun.flip Uri.with_scheme (Some "http")
      |> Fun.flip Uri.with_host (Some t.host)
      |> Fun.flip Uri.with_port (Some t.port)
      |> (fun uri -> if include_userinfo then Uri.with_userinfo uri userinfo else uri)

  end

  type t = {
    _proxy : (OBus_proxy.t [@sexp.opaque] [@yojson.opaque])
  ; _manager : (OBus_proxy.t [@sexp.opaque] [@yojson.opaque])
  ; id : string
  ; name : string
  ; type' : Technology.type'
  ; security: security list
  ; state : state
  ; strength : int option
  ; favorite : bool
  ; autoconnect : bool
  ; ipv4 : IPv4.t option
  ; ipv6 : IPv6.t option
  ; ethernet : Ethernet.t
  ; proxy : Proxy.t option
  ; nameservers : string list
  }
  [@@deriving sexp, yojson]

  (* Helper to parse a service from OBus *)
  let of_obus  manager context (path, properties) =
    let state_of_string = function
      | "idle" -> Some Idle
      | "failure" -> Some Failure
      | "association" -> Some Association
      | "configuration" -> Some Configuration
      | "ready" -> Some Ready
      | "disconnect" -> Some Disconnect
      | "online" -> Some Online
      | _ -> None
    in
    let security_of_string = function
      | "none" -> Some None
      | "psk" -> Some PSK
      | "wps" -> Some WPS
      | "ieee8021x" -> Some IEEE8021x
      | _ -> None
    in
    let security_of_obus v =
        let str_list = string_list_of_obus v in
        List.filter_map security_of_string str_list
    in
    let strength_of_obus v =
      try
        OBus_value.C.(v |> cast_single basic_byte)
        |> int_of_char
        |> CCOption.return
      with
      | _ -> None
    in
    let proxy_of_obus v =
      try
         let open OBus_value.C in
         let properties = v |> cast_single (dict string variant) in
         let proxy_method = properties |> List.assoc "Method" |> cast_single basic_string in
         if proxy_method = "manual" then
           properties
           |> List.assoc "Servers"
           |> cast_single (array basic_string)
           |> List.hd
           |> Proxy.validate
         else
           None
      with
        _ -> None
    in
    CCOption.(
      pure (fun name type' state strength favorite autoconnect ipv4 ipv4_user_config ipv6 ethernet proxy nameservers security ->
          { _proxy = OBus_proxy.make ~peer:(OBus_context.sender context) ~path:path
          ; _manager = manager
          ; id = path |> CCList.last 1 |> CCList.hd
          ; name ; type'; state; strength; favorite; autoconnect
          ; ipv4 = (if Option.is_some ipv4_user_config then ipv4_user_config else ipv4)
          ; ipv6; ethernet; proxy; nameservers; security
          })
      <*> (properties |> List.assoc_opt "Name" >>= string_of_obus)
      <*> (properties |> List.assoc_opt "Type" >>= string_of_obus >>= Technology.type_of_string)
      <*> (properties |> List.assoc_opt "State" >>= string_of_obus >>= state_of_string)
      <*> (properties |> List.assoc_opt "Strength" >>= strength_of_obus |> pure)
      <*> (properties |> List.assoc_opt "Favorite" >>= bool_of_obus)
      <*> (properties |> List.assoc_opt "AutoConnect" >>= bool_of_obus)
      <*> (properties |> List.assoc_opt "IPv4" >>= IPv4.of_obus |> pure)
      <*> (properties |> List.assoc_opt "IPv4.Configuration" >>= IPv4.of_obus |> pure)
      <*> (properties |> List.assoc_opt "IPv6" >>= IPv6.of_obus |> pure)
      <*> (properties |> List.assoc_opt "Ethernet" >>= Ethernet.of_obus)
      <*> (properties |> List.assoc_opt "Proxy" >>= proxy_of_obus |> pure)
      <*> (properties |> List.assoc_opt "Nameservers.Configuration" >|= string_list_of_obus)
      <*> (properties |> List.assoc_opt "Security" >|= security_of_obus))

  let is_connected t =
    match t.state with
    | Ready -> true
    | Online -> true
    | _ -> false

  let set_property service ~name ~value =
    OBus_method.call
      Connman_interfaces.Net_connman_Service.m_SetProperty
      service._proxy (name, value)

  let set_direct_proxy service =
    let dict =
      OBus_value.C.make_single
        (OBus_value.C.(dict string variant))
        [ ("Method", OBus_value.C.(make_single basic_string) "direct")
        ]
    in
    set_property service ~name:"Proxy.Configuration" ~value:dict

  let set_manual_proxy service proxy =
    let dict =
      OBus_value.C.make_single
        (OBus_value.C.(dict string variant))
        [ ("Method", OBus_value.C.(make_single basic_string) "manual")
        ; ("Servers", OBus_value.C.(make_single (array basic_string)) [Proxy.to_uri ~include_userinfo:true proxy |> Uri.to_string])
        ]
    in
    set_property service ~name:"Proxy.Configuration" ~value:dict


  let set_manual_ipv4 service ~address ~netmask ~gateway =
    let dict =
      OBus_value.C.make_single
        (OBus_value.C.(dict string variant))
        [ ("Method", OBus_value.C.(make_single basic_string) "manual")
        ; ("Address", OBus_value.C.(make_single basic_string) address)
        ; ("Netmask", OBus_value.C.(make_single basic_string) netmask)
        ; ("Gateway", OBus_value.C.(make_single basic_string) gateway)
        ]
    in
    set_property service ~name:"IPv4.Configuration" ~value:dict

  let set_dhcp_ipv4 service =
    let dict =
      OBus_value.C.make_single
        (OBus_value.C.(dict string variant))
        [("Method", OBus_value.C.(make_single basic_string) "dhcp")]
    in
    set_property service ~name:"IPv4.Configuration" ~value:dict

  let set_nameservers service nameservers =
    let config =
        OBus_value.C.make_single
          (OBus_value.C.(array basic_string)) nameservers
    in
    set_property service ~name:"Nameservers.Configuration" ~value:config



  let connect ?(input=Agent.None) service =
    let is_supported = List.exists
        (fun s -> List.mem s supported_security_protocols)
        service.security
    in
    let%lwt () = Logs_lwt.debug ~src:log_src
        (fun m -> m "connect to service %s" service.id)
    in

    (* Store agent error in a local mutable variable *)
    let agent_reported_error = ref Option.None in
    let on_agent_error msg = Lwt.return (agent_reported_error := Some msg) in

    (* Create and register an agent that will pass input to ConnMan *)
    let%lwt agent_path, agent = Agent.create ~input on_agent_error in
    let%lwt () = register_agent service._manager ~path:agent_path in

    let destroy_agent () =
      (* Cleanup and destroy agent *)
      let%lwt () = unregister_agent service._manager ~path:agent_path in
      Agent.destroy agent
    in

    let%lwt obus_resp = Lwt_result.catch (OBus_method.call
            Connman_interfaces.Net_connman_Service.m_Connect
            service._proxy)
    in
    let%lwt _ = Lwt_result.catch destroy_agent in
    match (obus_resp, !agent_reported_error) with
        | (Ok _, _) ->
            Lwt.return ()
        | (Error _, Some (ManagerError InvalidKey)) ->
            Lwt.fail_with "Passphrase is not valid or client is blocked. Please check the passphrase and then try to connect again."
        | (Error _, Some (ManagerError ConnectFailed)) ->
            Lwt.fail_with "Connection to network failed."
        | (Error _, Some (ManagerError Blocked)) ->
            Lwt.fail_with "Connection failed, deauthenticated by access point."
        | (Error exn, Some (ManagerError (Unknown err))) ->
            Lwt.fail_with (Printf.sprintf
                "Connection failed, unknown error reported by manager: %s
                 DBus connect exception: %s" err (Printexc.to_string exn)
            )
        | (Error exn, Some (AgentError err)) ->
            Lwt.fail_with (Printf.sprintf
                "Connection failed. %s
                 DBus connect exception: %s"
                 (Agent.agent_error_msg err) (Printexc.to_string exn)
            )
        | (Error exn, None) when not is_supported ->
            Lwt.fail_with (Printf.sprintf
                "Connection failed, none of the available authentication protocols are supported.
                Available protocols: %s
                Supported protocols: %s
               "
               (String.concat ", " @@
                    List.map string_of_security service.security)
               (String.concat ", " @@
                    List.map string_of_security supported_security_protocols)
            )
        | (Error exn, None) when
            OBus_error.name exn = "net.connman.Error.InvalidArguments" ->
            Lwt.fail_with (Printf.sprintf
                "Connection failed due to invalid arguments provided, the authentication protocol used by the access point is most likely unsupported"
            )
        | (Error exn, None) ->
            Lwt.fail_with (Printf.sprintf
                "Connection to network failed.
                 DBus connect exception: %s"
                    (Printexc.to_string exn)
            )

  let disconnect service =
    let%lwt () = Logs_lwt.debug ~src:log_src
        (fun m -> m "disconnect from service %s" service.id)
    in
    OBus_method.call
      Connman_interfaces.Net_connman_Service.m_Disconnect
      service._proxy ()

  let remove service =
    let%lwt () = Logs_lwt.debug ~src:log_src
        (fun m -> m "remove service %s" service.id)
    in
    OBus_method.call
      Connman_interfaces.Net_connman_Service.m_Remove
      service._proxy ()

end

module Manager =
struct
  type t = OBus_proxy.t

  let connect () =
    let%lwt system_bus = OBus_bus.system () in
    let peer = OBus_peer.make ~connection:system_bus ~name:"net.connman" in
    OBus_proxy.make ~peer ~path:[]
    |> return

  let get_technologies proxy =
    let%lwt (context, technologies) =
      OBus_method.call_with_context
        Net_connman_Manager.m_GetTechnologies proxy () in
    let to_technology (path, properties) : Technology.t option =
      CCOption.(pure
               (fun name type' powered connected : Technology.t ->
                  { _proxy = OBus_proxy.make ~peer:(OBus_context.sender context) ~path:path
                  ; name
                  ; type'
                  ; powered
                  ; connected
                  })
             <*> (properties |> List.assoc_opt "Name" >>= string_of_obus)
             <*> (properties
                  |> List.assoc_opt "Type"
                  >>= string_of_obus
                  >>= Technology.type_of_string)
             <*> (properties |> List.assoc_opt "Powered" >>= bool_of_obus)
             <*> (properties |> List.assoc_opt "Connected" >>= bool_of_obus)
            )
    in
    technologies
    |> CCList.filter_map to_technology
    |> return

  let get_services manager =
    let%lwt (context, services) =
      OBus_method.call_with_context
        Net_connman_Manager.m_GetServices manager ()
    in
    services
    |> CCList.filter_map (Service.of_obus manager context)
    |> return

  let get_services_signal manager =
    let%lwt initial_services = get_services manager in
    let%lwt service_changes =
      OBus_signal.map ignore
        (OBus_signal.make
           Net_connman_Manager.s_ServicesChanged manager)
      |> OBus_signal.connect
      >|= Lwt_react.E.map_s (fun () -> get_services manager)
    in
    Lwt_react.S.accum (service_changes |> Lwt_react.E.map (fun x _ -> x)) initial_services
    |> return

  (* Extract the proxy from the default route.
   *
   * The service with the default route will always be sorted at the top of the
   * list. (From connman doc/overview-api.txt *)
  let get_default_proxy manager =
    let open Service in
    let%lwt services = get_services manager in
    List.find_opt (fun s -> s.state = Online || s.state = Ready) services
    |> Fun.flip Option.bind (fun s -> s.proxy)
    |> return

end

(* Auto generated with obus-gen-client *)
module Net_connman_Clock =
struct
  open Net_connman_Clock


  let get_properties proxy =
    OBus_method.call m_GetProperties proxy ()

  let set_property proxy ~name ~value =
    OBus_method.call m_SetProperty proxy (name, value)

  let property_changed proxy =
    OBus_signal.make s_PropertyChanged proxy
end

module Net_connman_Manager =
struct
  open Net_connman_Manager


  let get_properties proxy =
    OBus_method.call m_GetProperties proxy ()

  let set_property proxy ~name ~value =
    OBus_method.call m_SetProperty proxy (name, value)

  let get_technologies proxy =
    let%lwt (context, technologies) = OBus_method.call_with_context m_GetTechnologies proxy () in
    let technologies = List.map (fun (x1, x2) -> (OBus_proxy.make ~peer:(OBus_context.sender context) ~path:x1, x2)) technologies in
    return technologies

  let get_services proxy =
    let%lwt (context, services) = OBus_method.call_with_context m_GetServices proxy () in
    let services = List.map (fun (x1, x2) -> (OBus_proxy.make ~peer:(OBus_context.sender context) ~path:x1, x2)) services in
    return services

  let get_peers proxy =
    let%lwt (context, peers) = OBus_method.call_with_context m_GetPeers proxy () in
    let peers = List.map (fun (x1, x2) -> (OBus_proxy.make ~peer:(OBus_context.sender context) ~path:x1, x2)) peers in
    return peers

  let register_agent proxy ~path =
    let path = OBus_proxy.path path in
    OBus_method.call m_RegisterAgent proxy path

  let unregister_agent proxy ~path =
    let path = OBus_proxy.path path in
    OBus_method.call m_UnregisterAgent proxy path

  let register_counter proxy ~path ~accuracy ~period =
    let path = OBus_proxy.path path in
    let accuracy = Int32.of_int accuracy in
    let period = Int32.of_int period in
    OBus_method.call m_RegisterCounter proxy (path, accuracy, period)

  let unregister_counter proxy ~path =
    let path = OBus_proxy.path path in
    OBus_method.call m_UnregisterCounter proxy path

  let create_session proxy ~settings ~notifier =
    let notifier = OBus_proxy.path notifier in
    let%lwt (context, session) = OBus_method.call_with_context m_CreateSession proxy (settings, notifier) in
    let session = OBus_proxy.make ~peer:(OBus_context.sender context) ~path:session in
    return session

  let destroy_session proxy ~session =
    let session = OBus_proxy.path session in
    OBus_method.call m_DestroySession proxy session

  let request_private_network proxy =
    let%lwt (context, (path, settings, socket)) = OBus_method.call_with_context m_RequestPrivateNetwork proxy () in
    let path = OBus_proxy.make ~peer:(OBus_context.sender context) ~path:path in
    return (path, settings, socket)

  let release_private_network proxy ~path =
    let path = OBus_proxy.path path in
    OBus_method.call m_ReleasePrivateNetwork proxy path

  let register_peer_service proxy ~specification ~master =
    OBus_method.call m_RegisterPeerService proxy (specification, master)

  let unregister_peer_service proxy ~specification =
    OBus_method.call m_UnregisterPeerService proxy specification

  let property_changed proxy =
    OBus_signal.make s_PropertyChanged proxy

  let technology_added proxy =
    OBus_signal.map_with_context
      (fun context (path, properties) ->
         let path = OBus_proxy.make ~peer:(OBus_context.sender context) ~path:path in
         (path, properties))
      (OBus_signal.make s_TechnologyAdded proxy)

  let technology_removed proxy =
    OBus_signal.map_with_context
      (fun context path ->
         let path = OBus_proxy.make ~peer:(OBus_context.sender context) ~path:path in
         path)
      (OBus_signal.make s_TechnologyRemoved proxy)

  let services_changed proxy =
    OBus_signal.map_with_context
      (fun context (changed, removed) ->
         let changed = List.map (fun (x1, x2) -> (OBus_proxy.make ~peer:(OBus_context.sender context) ~path:x1, x2)) changed in
         let removed = List.map (fun path -> OBus_proxy.make ~peer:(OBus_context.sender context) ~path) removed in
         (changed, removed))
      (OBus_signal.make s_ServicesChanged proxy)

  let peers_changed proxy =
    OBus_signal.map_with_context
      (fun context (changed, removed) ->
         let changed = List.map (fun (x1, x2) -> (OBus_proxy.make ~peer:(OBus_context.sender context) ~path:x1, x2)) changed in
         let removed = List.map (fun path -> OBus_proxy.make ~peer:(OBus_context.sender context) ~path) removed in
         (changed, removed))
      (OBus_signal.make s_PeersChanged proxy)
end

module Net_connman_Service =
struct
  open Net_connman_Service


  let set_property proxy ~name ~value =
    OBus_method.call m_SetProperty proxy (name, value)

  let clear_property proxy ~name =
    OBus_method.call m_ClearProperty proxy name

  let connect proxy =
    OBus_method.call m_Connect proxy ()

  let disconnect proxy =
    OBus_method.call m_Disconnect proxy ()

  let remove proxy =
    OBus_method.call m_Remove proxy ()

  let move_before proxy ~service =
    let service = OBus_proxy.path service in
    OBus_method.call m_MoveBefore proxy service

  let move_after proxy ~service =
    let service = OBus_proxy.path service in
    OBus_method.call m_MoveAfter proxy service

  let reset_counters proxy =
    OBus_method.call m_ResetCounters proxy ()

  let property_changed proxy =
    OBus_signal.make s_PropertyChanged proxy
end

module Net_connman_Technology =
struct
  open Net_connman_Technology


  let set_property proxy ~name ~value =
    OBus_method.call m_SetProperty proxy (name, value)

  let scan proxy =
    OBus_method.call m_Scan proxy ()

  let property_changed proxy =
    OBus_signal.make s_PropertyChanged proxy
end
