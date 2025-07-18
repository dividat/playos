open Lwt
open Opium_kernel.Rock
open Opium.App

let log_src = Logs.Src.create "gui"

(* Middleware that makes static content available *)
let static () =
  let static_dir = Util.resource_path (Fpath.v "static") in
  Logs.debug (fun m -> m "static content dir: %s" static_dir) ;
  Opium.Middleware.static ~local_path:static_dir ~uri_prefix:"/static" ()

let page html =
  let headers = Cohttp.Header.init_with "content-type" "text/html" in
  Format.asprintf "%a" (Tyxml.Html.pp ()) html
  |> Response.of_string_body ~headers

let resp_json ?code json =
  let headers = Cohttp.Header.init_with "content-type" "application/json" in
  Ezjsonm.value_to_string json |> Response.of_string_body ?code ~headers

let header key req = Cohttp.Header.get (Request.headers req) key

type 'a timeout_params =
  { duration : float
  ; on_timeout : unit -> 'a Lwt.t
  }

let with_timeout { duration; on_timeout } f =
  [ f ()
  ; (let%lwt () = Lwt_unix.sleep duration in
     on_timeout ()
    )
  ]
  |> Lwt.pick

(* Pretty error printing middleware *)
let error_handling =
  let open Opium_kernel.Rock in
  let filter handler req =
    (* Catch any exceptions that previously escaped Lwt *)
    match%lwt Lwt_result.catch (fun () -> handler req) with
    | Ok res ->
        return res
    | Error exn -> (
        let%lwt () =
          Logs_lwt.err (fun m -> m "GUI Error: %s" (Printexc.to_string exn))
        in
        match header "accept" req with
        | Some "application/json" ->
            (* for testing *)
            Lwt.return
            @@ resp_json ~code:`Internal_server_error
            @@ `O
                 [ ("error", `Bool true)
                 ; ("message", `String (Printexc.to_string exn))
                 ]
        | _ ->
            Lwt.return
              (page
                 (Error_page.html
                    { message =
                        exn
                        |> Sexplib.Std.sexp_of_exn
                        |> Sexplib.Sexp.to_string_hum
                    ; request =
                        req |> Request.sexp_of_t |> Sexplib.Sexp.to_string_hum
                    }
                 )
              )
      )
  in
  Middleware.create ~name:"Error" ~filter

(** Display basic server information *)
module InfoGui = struct
  let build app =
    app
    |> get "/info" (fun _ ->
           let%lwt server_info = Info.get () in
           Lwt.return (page (Info_page.html server_info))
       )
end

(** Localization GUI *)
module LocalizationGui = struct
  let overview _req =
    let%lwt td_daemon = Timedate.daemon () in
    let%lwt current_timezone = Timedate.get_configured_timezone () in
    let%lwt all_timezones = Timedate.get_available_timezones td_daemon in
    let timezone_groups =
      List.fold_right
        (fun tz groups ->
          let re_spaced =
            String.map (fun c -> if Char.equal c '_' then ' ' else c) tz
          in
          let group_id, name =
            match String.split_on_char '/' re_spaced |> List.rev with
            (* An unscoped entry, e.g. UTC. *)
            | [ singleton ] ->
                (singleton, singleton)
            (* A humble entry, likely scoped to continent, e.g. Europe/Amsterdam. *)
            | [ name; group_id ] ->
                (group_id, name)
            (* A multi-hierarchical entry, e.g. America/Argentina/Buenos_Aires. *)
            | name :: group_sections ->
                (String.concat "/" (List.rev group_sections), name)
            (* Not a sensible outcome. *)
            | [] ->
                (re_spaced, re_spaced)
          in
          let prev_entries =
            match List.assoc_opt group_id groups with
            | Some entries ->
                entries
            | None ->
                []
          in
          (group_id, (tz, name) :: prev_entries)
          :: List.remove_assoc group_id groups
        )
        all_timezones []
    in
    let%lwt current_lang = Locale.get_lang () in
    let langs =
      [ ("cs_CZ.UTF-8", "Czech")
      ; ("nl_NL.UTF-8", "Dutch")
      ; ("en_UK.UTF-8", "English (UK)")
      ; ("en_US.UTF-8", "English (US)")
      ; ("fi_FI.UTF-8", "Finnish")
      ; ("fr_FR.UTF-8", "French")
      ; ("de_DE.UTF-8", "German")
      ; ("it_IT.UTF-8", "Italian")
      ; ("pl_PL.UTF-8", "Polish")
      ; ("es_ES.UTF-8", "Spanish")
      ]
    in
    let%lwt current_keymap = Locale.get_keymap () in
    let keymaps =
      [ ("cz", "Czech")
      ; ("nl", "Dutch")
      ; ("gb", "English (UK)")
      ; ("us", "English (US)")
      ; ("fi", "Finnish")
      ; ("fr", "French")
      ; ("de", "German")
      ; ("ch", "German (Switzerland)")
      ; ("it", "Italian")
      ; ("pl", "Polish")
      ; ("es", "Spanish")
      ]
    in
    let%lwt current_scaling = Screen_settings.get_scaling () in
    Lwt.return
      (page
         (Localization_page.html
            { timezone_groups
            ; current_timezone
            ; langs
            ; current_lang
            ; keymaps
            ; current_keymap
            ; current_scaling
            }
         )
      )

  let set_timezone req =
    let%lwt _td_daemon = Timedate.daemon () in
    let%lwt form_data = urlencoded_pairs_of_body req in
    let%lwt _ =
      match form_data |> List.assoc_opt "timezone" with
      | Some [ tz_id ] ->
          Timedate.set_timezone tz_id
      | _ ->
          return ()
    in
    "/localization" |> Uri.of_string |> redirect'

  let set_lang req =
    let%lwt form_data = urlencoded_pairs_of_body req in
    let%lwt _ =
      match form_data |> List.assoc_opt "lang" with
      | Some [ lang ] ->
          Locale.set_lang lang
      | _ ->
          return ()
    in
    "/localization" |> Uri.of_string |> redirect'

  let set_keymap req =
    let%lwt form_data = urlencoded_pairs_of_body req in
    let%lwt _ =
      match form_data |> List.assoc_opt "keymap" with
      | Some [ keymap ] ->
          Locale.set_keymap keymap
      | _ ->
          return ()
    in
    "/localization" |> Uri.of_string |> redirect'

  let set_scaling req =
    let%lwt form_data = urlencoded_pairs_of_body req in
    let%lwt _ =
      match form_data |> List.assoc_opt "scaling" with
      | Some [ opt ] -> (
        match Screen_settings.scaling_of_string opt with
        | Some s ->
            Screen_settings.set_scaling s
        | None ->
            fail_with (Format.sprintf "Unknown screen setting: %s" opt)
      )
      | _ ->
          return ()
    in
    "/localization" |> Uri.of_string |> redirect'

  let build app =
    app
    |> get "/localization" overview
    |> post "/localization/timezone" set_timezone
    |> post "/localization/lang" set_lang
    |> post "/localization/keymap" set_keymap
    |> post "/localization/scaling" set_scaling
end

(** Network configuration GUI *)
module NetworkGui = struct
  open Connman

  let overview ~(connman : Manager.t) req =
    let%lwt all_services = Manager.get_services connman in
    let%lwt proxy = Manager.get_default_proxy connman in
    let%lwt interfaces = Network.Interface.get_all () in
    let pp_proxy p =
      let uri =
        p |> Service.Proxy.to_uri ~include_userinfo:false |> Uri.to_string
      in
      match p.credentials with
      | Some { user; password } ->
          let password_indication =
            if password = "" then "" else ", password: *****"
          in
          uri ^ " (user: " ^ user ^ password_indication ^ ")"
      | None ->
          uri
    in
    let params : Network_list_page.params =
      { proxy = proxy |> Option.map pp_proxy
      ; services = all_services
      ; interfaces
      }
    in
    match header "accept" req with
    | Some "application/json" ->
        Lwt.return @@ resp_json @@ Network_list_page.params_to_jsonm params
    | _ ->
        Lwt.return (page (Network_list_page.html params))

  (** Internet status **)
  let internet_status ~connman _ =
    let%lwt proxy = Manager.get_default_proxy connman in
    match%lwt
      Curl.request
        ?proxy:(Option.map (Service.Proxy.to_uri ~include_userinfo:true) proxy)
        (Uri.of_string "http://captive.dividat.com/")
    with
    | RequestSuccess (code, response) ->
        `String response |> respond ?code:(Some (`Code code)) |> Lwt.return
    | RequestFailure err ->
        `String
          (Format.sprintf "Error reaching captive portal: %s"
             (Curl.pretty_print_error err)
          )
        |> respond ?code:(Some `Service_unavailable)
        |> Lwt.return

  (** Helper to find a service by id *)
  let with_service ~connman id =
    let%lwt services = Connman.Manager.get_services connman in
    match List.find_opt (fun s -> s.Service.id = id) services with
    | Some s ->
        return s
    | None ->
        fail_with (Format.sprintf "Service does not exist (%s)" id)

  let details ~connman req =
    let service_id = param req "id" in
    let%lwt service = with_service ~connman service_id in
    Lwt.return (page (Network_details_page.html service))

  (** Validate a proxy, fail if the proxy is given but invalid *)
  let make_proxy current_proxy_opt form_data =
    let open Service.Proxy in
    let non_empty s = if s = "" then None else Some s in
    let opt_int_of_string s = try Some (int_of_string s) with _ -> None in
    match form_data |> List.assoc_opt "proxy_enabled" with
    | None ->
        return None
    | Some _ -> (
        let host_input =
          form_data |> List.assoc "proxy_host" |> List.hd |> non_empty
        in
        let port_input =
          form_data |> List.assoc "proxy_port" |> List.hd |> opt_int_of_string
        in
        let user_input =
          form_data |> List.assoc "proxy_user" |> List.hd |> non_empty
        in
        let password_input =
          form_data |> List.assoc "proxy_password" |> List.hd |> non_empty
        in
        let keep_password =
          form_data |> List.assoc_opt "keep_password" |> Option.is_some
        in
        let password =
          match (keep_password, current_proxy_opt) with
          | true, Some { host; port; credentials = Some { user; password } } ->
              if
                host_input = Some host
                && port_input = Some port
                && user_input = Some user
              then
                (* Proxy configuration wasn't touched, password may be preserved. *)
                Ok (Some password)
              else
                (* Proxy configuration was touched, demand new password to avoid
                   disclosing to untrusted server. *)
                Error
                  "Password needs to be provided when changing proxy \
                   configuration."
          | true, _ ->
              Error
                "Failure to retrieve proxy password. Please re-submit the form."
          | _ ->
              Ok password_input
        in
        match (host_input, port_input, user_input, password) with
        (* Configuration without credentials was submitted *)
        | Some host, Some port, None, Ok None ->
            return (Some (Service.Proxy.make host port))
        (* Configuration with credentials was submitted *)
        | Some host, Some port, Some user, Ok password ->
            return
              (Some
                 (Service.Proxy.make ~user
                    ~password:(Option.value ~default:"" password)
                    host port
                 )
              )
        (* Configuration without user but with password was submitted *)
        | _, _, None, Ok (Some _) ->
            fail_with "A user is required if a password is provided"
        (* Password retrieval error *)
        | _, _, _, Error msg ->
            fail_with msg
        (* Incomplete server information *)
        | _ ->
            fail_with "A host and port are required to configure a proxy server"
      )

  (** Set static IP configuration on a service *)
  let update_static_ip service form_data =
    let get_prop s = form_data |> List.assoc s |> List.hd in
    match form_data |> List.assoc_opt "static_ip_enabled" with
    | None ->
        let%lwt () =
          Logs_lwt.err ~src:log_src (fun m ->
              m "disabling static ip %s" (get_prop "static_ip_address")
          )
        in
        let%lwt () = Connman.Service.set_dhcp_ipv4 service in
        let%lwt () = Connman.Service.set_nameservers service [] in
        return ()
    | Some _ ->
        let address = get_prop "static_ip_address" in
        let netmask = get_prop "static_ip_netmask" in
        let gateway = get_prop "static_ip_gateway" in
        let nameservers =
          get_prop "static_ip_nameservers"
          |> String.split_on_char ','
          |> List.map String.trim
        in
        let%lwt () =
          Connman.Service.set_manual_ipv4 service ~address ~netmask ~gateway
        in
        let%lwt () = Connman.Service.set_nameservers service nameservers in
        return ()

  (** Connect to a service *)
  let connect ~(connman : Connman.Manager.t) req =
    let%lwt form_data = urlencoded_pairs_of_body req in
    let passphrase =
      match form_data |> List.assoc_opt "passphrase" with
      | Some [ passphrase ] ->
          Connman.Agent.Passphrase passphrase
      | _ ->
          Connman.Agent.None
    in
    let%lwt service = with_service ~connman (param req "id") in
    let%lwt () = Connman.Service.connect ~input:passphrase service in
    redirect' (Uri.of_string "/network")

  (** Update a service *)
  let update ~(connman : Connman.Manager.t) req =
    let%lwt form_data = urlencoded_pairs_of_body req in
    let%lwt service = with_service ~connman (param req "id") in
    (* Static IP *)
    let%lwt () = update_static_ip service form_data in
    (* Proxy *)
    let%lwt current_proxy = Manager.get_default_proxy connman in
    let%lwt () =
      match%lwt make_proxy current_proxy form_data with
      | None ->
          Connman.Service.set_direct_proxy service
      | Some proxy ->
          Connman.Service.set_manual_proxy service proxy
    in
    (* Grant time for changes to take effect and return to overview *)
    let%lwt () = Lwt_unix.sleep 0.5 in
    redirect' (Uri.of_string "/network")

  (** Remove a service **)
  let remove ~(connman : Connman.Manager.t) req =
    let%lwt service = with_service ~connman (param req "id") in
    (* Clear settings. *)
    let%lwt () = Connman.Service.set_direct_proxy service in
    let%lwt () = Connman.Service.set_nameservers service [] in
    let%lwt () = Connman.Service.set_dhcp_ipv4 service in
    let%lwt () = Connman.Service.remove service in
    redirect' (Uri.of_string "/network")

  let build ~(connman : Connman.Manager.t) app =
    app
    |> get "/network" (overview ~connman)
    |> get "/network/:id" (details ~connman)
    |> post "/network/:id/connect" (connect ~connman)
    |> post "/network/:id/update" (update ~connman)
    |> post "/network/:id/remove" (remove ~connman)
    |> get "/internet/status" (internet_status ~connman)
end

module StatusGui = struct
  open Status_page

  let shutdown () = Util.run_cmd_no_stdout [| "halt"; "--poweroff" |]

  let reboot () = Util.run_cmd_no_stdout [| "reboot" |]

  let switch_slot rauc target_slot =
    let%lwt () = Rauc.mark_active rauc target_slot in
    reboot ()

  let factory_reset systemd =
    let%lwt () =
      Logs_lwt.info ~src:log_src (fun m -> m "Enabling persistent data wipe...")
    in
    let%lwt () =
      Systemd.Manager.start_unit systemd "playos-wipe-persistent-data.service"
    in
    let%lwt () =
      Logs_lwt.info ~src:log_src (fun m ->
          m "Persistent data wipe is enabled, rebooting."
      )
    in
    reboot ()

  let get_status ~health_s ~(update_s : Update.state React.signal) ~rauc =
    let health_state = health_s |> Lwt_react.S.value in
    let update_state = update_s |> Lwt_react.S.value in
    let%lwt watchdog_disabled = Network_watchdog.is_disabled () in
    let%lwt booted_slot = Rauc.get_booted_slot rauc in
    let%lwt rauc =
      match update_state.process_state with
      (* RAUC status is not meaningful while installing
         https://github.com/rauc/rauc/issues/416
      *)
      | Update.Installing _ ->
          Lwt.return Status_page.Installing
      | _ ->
          Lwt_result.catch (fun () -> Rauc.get_status rauc)
          >|= Result.fold
                ~ok:(fun s -> Status_page.Status s)
                ~error:(fun e -> Status_page.Error (Printexc.to_string e))
    in
    { health = health_state
    ; update = update_state
    ; rauc
    ; booted_slot
    ; watchdog_disabled
    }
    |> return

  let exec_and_resp_ok f req = f req >|= (fun _ -> `String "Ok") >|= respond

  let build ~systemd ~health_s ~update_s ~rauc app =
    app
    |> post "/system/shutdown" (exec_and_resp_ok (fun _ -> shutdown ()))
    |> post "/system/reboot" (exec_and_resp_ok (fun _ -> reboot ()))
    |> post "/system/factory-reset"
         (exec_and_resp_ok (fun _ -> factory_reset systemd))
    |> post "/system/switch/:slot"
         (exec_and_resp_ok (fun req ->
              switch_slot rauc (param req "slot" |> Rauc.Slot.t_of_string)
          )
         )
    |> post "/watchdog/enable" (fun _req ->
           let%lwt () = Network_watchdog.enable systemd in
           redirect' (Uri.of_string "/status")
       )
    |> post "/watchdog/disable" (fun _req ->
           let%lwt () = Network_watchdog.disable systemd in
           redirect' (Uri.of_string "/status")
       )
    |> get "/status" (fun _req ->
           let%lwt status = get_status ~update_s ~health_s ~rauc in
           Lwt.return (page (Status_page.html status))
       )
end

module ChangelogGui = struct
  let build app =
    app
    |> get "/changelog" (fun _ ->
           let%lwt changelog =
             Util.read_from_file log_src
               (Util.resource_path (Fpath.v "Changelog.html"))
           in
           Lwt.return (page (Changelog_page.html changelog))
       )
end

module LicensingGui = struct
  let build app =
    app
    |> get "/licensing" (fun _ ->
           let%lwt p = Licensing_page.html in
           Lwt.return (page p)
       )
end

module RemoteMaintenanceGui = struct
  let rec wait_until_zerotier_is_on () =
    match%lwt Zerotier.get_status () with
    | Ok _ ->
        redirect' (Uri.of_string "/info")
    | Error _ ->
        let%lwt () = Lwt_unix.sleep 0.1 in
        wait_until_zerotier_is_on ()

  let build ~systemd app =
    app
    |> post "/remote-maintenance/enable" (fun _ ->
           let%lwt () =
             Systemd.Manager.start_unit systemd "zerotierone.service"
           in
           with_timeout
             { duration = 2.0
             ; on_timeout =
                 (fun () ->
                   let msg = "Timeout starting remote maintenance service." in
                   let%lwt () = Logs_lwt.err (fun m -> m "%s" msg) in
                   fail_with msg
                 )
             }
             wait_until_zerotier_is_on
       )
    |> post "/remote-maintenance/disable" (fun _ ->
           let%lwt () =
             Systemd.Manager.stop_unit systemd "zerotierone.service"
           in
           redirect' (Uri.of_string "/info")
       )
end

let routes ~systemd ~health_s ~update_s ~rauc ~connman app =
  app
  |> middleware (static ())
  |> middleware error_handling
  |> get "/" (fun _ -> "/info" |> Uri.of_string |> redirect')
  |> InfoGui.build
  |> NetworkGui.build ~connman
  |> LocalizationGui.build
  |> StatusGui.build ~systemd ~health_s ~update_s ~rauc
  |> ChangelogGui.build
  |> LicensingGui.build
  |> RemoteMaintenanceGui.build ~systemd

(* NOTE: probably easier to create a record with all the inputs instead of passing in x arguments. *)
let start ~port ~systemd ~health_s ~update_s ~rauc ~connman =
  empty
  |> Opium.App.port port
  |> routes ~systemd ~health_s ~update_s ~rauc ~connman
  |> start
