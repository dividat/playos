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

module Technology =
struct
  type type' =
    | Wifi
    | Ethernet
    | Bluetooth
    | P2P
  [@@deriving sexp]

  let type_of_string = function
    | "wifi" -> Some Wifi
    | "ethernet" -> Some Ethernet
    | "bluetooth" -> Some Bluetooth
    | "p2p" -> Some P2P
    | _ -> None

  type t = {
    _proxy: OBus_proxy.t sexp_opaque
  ; name : string
  ; type' : type'
  ; powered : bool
  ; connected : bool
  } [@@deriving sexp]

  let set_property proxy ~name ~value =
    OBus_method.call
      Connman_interfaces.Net_connman_Technology.m_SetProperty proxy (name, value)

  let enable t =
    set_property t._proxy "Powered" (true |> OBus_value.C.(make_single basic_boolean))

  let disable t =
    set_property t._proxy "Powered" (false |> OBus_value.C.(make_single basic_boolean))

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
  [@@deriving sexp]

  type t = input OBus_object.t

  let report_error input service msg =
    let%lwt () = Logs_lwt.err ~src:log_src
        (fun m -> m "error reported to agent: %s" msg)
    in
    return_unit

  let request_input input service (fields: (string * OBus_value.V.single) list) =
    let%lwt () = Logs_lwt.debug ~src:log_src
        (fun m -> m "input requested from agent for service %s"
            (String.concat "/" service)
        )
    in
    match input with
    | Passphrase p ->
      (match List.assoc_opt "Passphrase" fields with
       | Some _ ->
         return [ "Passphrase", p |> OBus_value.C.(make_single basic_string)]
       | None ->
         let%lwt () = Logs_lwt.err ~src:log_src
             (fun m -> m "Passphrase available as input but not being requested")
         in
         OBus_error.make "net.connman.Agent.Error.Canceled" "."
         |> Lwt.fail
      )
    | None ->
      let%lwt () = Logs_lwt.err ~src:log_src
          (fun m -> m "input requested from agent but none available.")
      in
      OBus_error.make "net.connman.Agent.Error.Canceled" "No input available."
      |> Lwt.fail


  let request_browser input service url =
    let%lwt () = Logs_lwt.err ~src:log_src
        (fun m -> m "agent requested to open browser to url: %s" url)
    in
    OBus_error.make "net.connman.Agent.Error.Canceled" "Can not open browser."
    |> Lwt.fail

  let cancel input =
    return_unit

  let release input =
    return_unit

  let interface =
    Connman_interfaces.Net_connman_Agent.make {
      m_ReportError = (
        fun obj (service, msg) ->
          report_error (OBus_object.get obj) service msg
      );
      m_RequestInput = (
        fun obj (x1, x2) ->
          request_input (OBus_object.get obj) x1 x2
      );
      m_RequestBrowser = (
        fun obj (x1, x2) ->
          request_browser (OBus_object.get obj) x1 x2
      );
      m_Cancel = (
        fun obj () ->
          cancel (OBus_object.get obj)
      );
      m_Release = (
        fun obj () ->
          release (OBus_object.get obj)
      );
    }

  let create ~(input:input) =
    let%lwt system_bus = OBus_bus.system () in
    let path = [ "net"; "connman"; "agent"
               ; Random.int 9999 |> string_of_int ]
    in
    let%lwt () = Logs_lwt.debug ~src:log_src
        (fun m -> m "creating connman agent at %s" (String.concat "/" path))
    in
    let obj = OBus_object.make ~interfaces:[interface] path in
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
  [@@deriving sexp]

  module IPv4 =
  struct
    type t = {
      method' : string
    ; address : string
    ; netmask : string
    ; gateway : string
    }
    [@@deriving sexp]

    let of_obus v =
      (fun () ->
         let open OBus_value.C in
         let properties = v |> cast_single (dict string variant) in
         { method' = properties |> List.assoc "Method" |> cast_single basic_string
         ; address = properties |> List.assoc "Address" |> cast_single basic_string
         ; netmask = properties |> List.assoc "Netmask" |> cast_single basic_string
         ; gateway = properties |> List.assoc "Gateway" |> cast_single basic_string
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
    ; gateway : string
    ; privacy : string
    }
    [@@deriving sexp]

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
         ; gateway = properties |> List.assoc "Gateway" |> cast_single basic_string
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
    [@@deriving sexp]

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

  type t = {
    _proxy : OBus_proxy.t sexp_opaque
  ; _manager : OBus_proxy.t sexp_opaque
  ; id : string
  ; name : string
  ; type' : Technology.type'
  ; state : state
  ; strength : int option
  ; favorite : bool
  ; autoconnect : bool
  ; ipv4 : IPv4.t option
  ; ipv6 : IPv6.t option
  ; ethernet : Ethernet.t
  }
  [@@deriving sexp]

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
    let strength_of_obus v =
      try
        OBus_value.C.(v |> cast_single basic_byte)
        |> int_of_char
        |> CCOpt.return
      with
      | _ -> None
    in
    CCOpt.(
      pure (fun name type' state strength favorite autoconnect ipv4 ipv6 ethernet ->
          { _proxy = OBus_proxy.make (OBus_context.sender context) path
          ; _manager = manager
          ; id = path |> CCList.last 1 |> CCList.hd
          ; name ; type'; state; strength; favorite; autoconnect
          ; ipv4; ipv6; ethernet
          })
      <*> (properties |> List.assoc_opt "Name" >>= string_of_obus)
      <*> (properties |> List.assoc_opt "Type" >>= string_of_obus >>= Technology.type_of_string)
      <*> (properties |> List.assoc_opt "State" >>= string_of_obus >>= state_of_string)
      <*> (properties |> List.assoc_opt "Strength" >>= strength_of_obus |> pure)
      <*> (properties |> List.assoc_opt "Favorite" >>= bool_of_obus)
      <*> (properties |> List.assoc_opt "AutoConnect" >>= bool_of_obus)
      <*> (properties |> List.assoc_opt "IPv4" >>= IPv4.of_obus |> pure)
      <*> (properties |> List.assoc_opt "IPv6" >>= IPv6.of_obus |> pure)
      <*> (properties |> List.assoc_opt "Ethernet" >>= Ethernet.of_obus)
    )


  let is_connected t =
    match t.state with
    | Ready -> true
    | Online -> true
    | _ -> false

  let to_json s =
    Ezjsonm.dict [
      "id", s.id |> Ezjsonm.string
    ; "name", s.name |> Ezjsonm.string
    ; "favorite", s.favorite |> Ezjsonm.bool
    ; "connected", s |> is_connected |> Ezjsonm.bool
    ; "strength", (match s.strength with
      | Some s -> string_of_int s ^ "%"
      | None -> "") |> Ezjsonm.string
    ; "properties", s |> sexp_of_t |> Sexplib.Sexp.to_string_hum |> Ezjsonm.string
    ]

  let set_property service ~name ~value =
    OBus_method.call
      Connman_interfaces.Net_connman_Service.m_SetProperty
      service._proxy (name, value)

  let connect ?(input=Agent.None) service =
    let%lwt () = Logs_lwt.debug ~src:log_src
        (fun m -> m "connect to service %s" service.id)
    in

    (* Create and register an agent that will pass input to ConnMan *)
    let%lwt agent_path, agent = Agent.create input in
    let%lwt () = register_agent service._manager agent_path in

    begin
      (* Connect to service *)
      OBus_method.call
        Connman_interfaces.Net_connman_Service.m_Connect
        service._proxy ()
    end
    [%lwt.finally
      (* Cleanup and destroy agent *)
      let%lwt () = unregister_agent service._manager agent_path in
      Agent.destroy agent]

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
    let peer = OBus_peer.make system_bus "net.connman" in
    OBus_proxy.make peer []
    |> return

  let get_technologies proxy =
    let%lwt (context, technologies) =
      OBus_method.call_with_context
        Net_connman_Manager.m_GetTechnologies proxy () in
    let to_technology (path, properties) : Technology.t option =
      CCOpt.(pure
               (fun name type' powered connected : Technology.t ->
                  { _proxy = OBus_proxy.make (OBus_context.sender context) path
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
    let technologies = List.map (fun (x1, x2) -> (OBus_proxy.make (OBus_context.sender context) x1, x2)) technologies in
    return technologies

  let get_services proxy =
    let%lwt (context, services) = OBus_method.call_with_context m_GetServices proxy () in
    let services = List.map (fun (x1, x2) -> (OBus_proxy.make (OBus_context.sender context) x1, x2)) services in
    return services

  let get_peers proxy =
    let%lwt (context, peers) = OBus_method.call_with_context m_GetPeers proxy () in
    let peers = List.map (fun (x1, x2) -> (OBus_proxy.make (OBus_context.sender context) x1, x2)) peers in
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
    let session = OBus_proxy.make (OBus_context.sender context) session in
    return session

  let destroy_session proxy ~session =
    let session = OBus_proxy.path session in
    OBus_method.call m_DestroySession proxy session

  let request_private_network proxy =
    let%lwt (context, (path, settings, socket)) = OBus_method.call_with_context m_RequestPrivateNetwork proxy () in
    let path = OBus_proxy.make (OBus_context.sender context) path in
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
         let path = OBus_proxy.make (OBus_context.sender context) path in
         (path, properties))
      (OBus_signal.make s_TechnologyAdded proxy)

  let technology_removed proxy =
    OBus_signal.map_with_context
      (fun context path ->
         let path = OBus_proxy.make (OBus_context.sender context) path in
         path)
      (OBus_signal.make s_TechnologyRemoved proxy)

  let services_changed proxy =
    OBus_signal.map_with_context
      (fun context (changed, removed) ->
         let changed = List.map (fun (x1, x2) -> (OBus_proxy.make (OBus_context.sender context) x1, x2)) changed in
         let removed = List.map (fun path -> OBus_proxy.make ~peer:(OBus_context.sender context) ~path) removed in
         (changed, removed))
      (OBus_signal.make s_ServicesChanged proxy)

  let peers_changed proxy =
    OBus_signal.map_with_context
      (fun context (changed, removed) ->
         let changed = List.map (fun (x1, x2) -> (OBus_proxy.make (OBus_context.sender context) x1, x2)) changed in
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
