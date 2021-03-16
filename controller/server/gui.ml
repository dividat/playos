open Lwt
open Sexplib.Std
open Opium_kernel.Rock
open Opium.App

let log_src = Logs.Src.create "gui"

(* Require the resource directory to be at a directory fixed to the binary
 * location. This is not optimal, but works for the moment. *)
let resource_path end_path =
  let open Fpath in
  (Sys.argv.(0) |> v |> parent) / ".." / "share" // end_path
  |> to_string


(* Middleware that makes static content available *)
let static () =
  let static_dir = resource_path (Fpath.v "static") in
  Logs.debug (fun m -> m "static content dir: %s" static_dir);
  Opium.Middleware.static ~local_path:static_dir ~uri_prefix:"/static" ()

let page html =
  Format.asprintf "%a" (Tyxml.Html.pp ()) html
  |> Response.of_string_body

let success content =
  page (Page.html (Tyxml.Html.txt content))

type 'a timeout_params =
  { duration: float
  ; on_timeout: unit -> 'a Lwt.t
  }

let with_timeout { duration; on_timeout } f =
  [ f ()
  ; (let%lwt () = Lwt_unix.sleep duration in on_timeout ())
  ] |> Lwt.pick

(* Pretty error printing middleware *)
let error_handling =
  let open Opium_kernel.Rock in
  let filter handler req =
    (* Catch any exceptions that previously escaped Lwt *)
    let res = try handler req with exn -> Lwt.fail exn in
    match%lwt res |> Lwt_result.catch with
    | Ok res ->
      return res
    | Error exn ->
      let%lwt () = Logs_lwt.err (fun m -> m "GUI Error: %s" (Printexc.to_string exn)) in
      Lwt.return (page (Error_page.html
        { message = exn
            |> Sexplib.Std.sexp_of_exn
            |> Sexplib.Sexp.to_string_hum
        ; request = req
            |> Request.sexp_of_t
            |> Sexplib.Sexp.to_string_hum
        }))
  in
  Middleware.create ~name:"Error" ~filter

(** Display basic server information *)
module InfoGui = struct
  let build app =
    app
    |> get "/info" (fun _ ->
        let%lwt server_info = Info.get () in
        Lwt.return (page (Info_page.html server_info)))
end

(** Localization GUI *)
module LocalizationGui = struct
  let overview req =
    let%lwt td_daemon = Timedate.daemon () in
    let%lwt current_timezone = Timedate.get_configured_timezone () in
    let%lwt all_timezones = Timedate.get_available_timezones td_daemon in
    let timezone_groups =
      List.fold_right
        (fun tz groups ->
          let re_spaced = String.map (fun c -> if Char.equal c '_' then ' ' else c) tz in
          let group_id, name = match String.split_on_char '/' re_spaced |> List.rev with
            (* An unscoped entry, e.g. UTC. *)
            | [ singleton ] -> singleton, singleton
            (* A humble entry, likely scoped to continent, e.g. Europe/Amsterdam. *)
            | [ name; group_id ] -> group_id, name
            (* A multi-hierarchical entry, e.g. America/Argentina/Buenos_Aires. *)
            | name :: group_sections -> String.concat "/" (List.rev group_sections), name
            (* Not a sensible outcome. *)
            | [] -> re_spaced, re_spaced
          in
          let prev_entries = match List.assoc_opt group_id groups with
            | Some entries -> entries
            | None -> []
          in
          ( group_id, (tz, name) :: prev_entries)
          :: List.remove_assoc group_id groups
        )
        all_timezones
        []
    in
    let%lwt current_lang = Locale.get_lang () in
    let langs =
      [ "nl_NL.UTF-8", "Dutch"
      ; "en_UK.UTF-8", "English (UK)"
      ; "en_US.UTF-8", "English (US)"
      ; "fi_FI.UTF-8", "Finnish"
      ; "fr_FR.UTF-8", "French"
      ; "de_DE.UTF-8", "German"
      ; "it_IT.UTF-8", "Italian"
      ; "es_ES.UTF-8", "Spanish"
      ]
    in
    let%lwt current_keymap = Locale.get_keymap () in
    let keymaps =
      [ "nl", "Dutch"
      ; "gb", "English (UK)"
      ; "us", "English (US)"
      ; "fi", "Finnish"
      ; "fr", "French"
      ; "de", "German"
      ; "ch", "German (Switzerland)"
      ; "it", "Italian"
      ; "es", "Spanish"
      ]
    in
    Lwt.return (page (Localization_page.html
      { timezone_groups
      ; current_timezone
      ; langs
      ; current_lang
      ; keymaps
      ; current_keymap
      }))

  let set_timezone req =
    let%lwt td_daemon = Timedate.daemon () in
    let%lwt form_data =
      urlencoded_pairs_of_body req
    in
    let%lwt _ =
      match form_data |> List.assoc_opt "timezone" with
      | Some [ tz_id ] ->
        Timedate.set_timezone tz_id
      | _ ->
        return ()
    in
    "/localization" |> Uri.of_string |> redirect'

  let set_lang req =
    let%lwt form_data =
      urlencoded_pairs_of_body req
    in
    let%lwt _ =
      match form_data |> List.assoc_opt "lang" with
      | Some [ lang ] ->
        Locale.set_lang lang
      | _ ->
        return ()
    in
    "/localization" |> Uri.of_string |> redirect'

  let set_keymap req =
    let%lwt form_data =
      urlencoded_pairs_of_body req
    in
    let%lwt _ =
      match form_data |> List.assoc_opt "keymap" with
      | Some [ keymap ] ->
        Locale.set_keymap keymap
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
end

(** Network configuration GUI *)
module NetworkGui = struct

  open Connman
  open Network

  let blur_service_proxy_password s =
    let open Service in
    let blur p = Proxy.validate p |> Option.map (Proxy.to_string ~hide_password:true) in
    { s with proxy = s.proxy |> Base.Fn.flip Option.bind blur }

  let overview ~(connman:Manager.t) req =

    let%lwt all_services = Manager.get_services connman in

    let proxy = Proxy.from_default_service all_services in

    let check_timeout =
      Option.bind (Uri.get_query_param (Request.uri req) "timeout") Float.of_string_opt
        |> Option.map (min 5.0)
        |> Option.map (max 0.0)
        |> Option.value ~default:0.2
    in

    let%lwt is_internet_connected =
      with_timeout
        { duration = check_timeout
        ; on_timeout = fun () ->
            let%lwt () = Logs_lwt.err (fun m -> m "Timeout reaching captive portal (%f s)" check_timeout) in
            return false
        }
        (fun () ->
            match%lwt Curl.request ?proxy (Uri.of_string "http://captive.dividat.com/") with
            | RequestSuccess (200, _) ->
              return true
            | RequestSuccess (status, _) ->
              let%lwt () = Logs_lwt.err (fun m -> m "Non-OK status code reaching captive portal: %d" status) in
              return false
            | RequestFailure err ->
              let%lwt () = Logs_lwt.err (fun m -> m "Error reaching captive portal: %s" (Curl.pretty_print_error err)) in
              return false)
    in

    (* If not connected show all services, otherwise show services that are connected *)
    let showed_services =
      all_services
        |> List.filter (fun s -> not is_internet_connected || Service.is_connected s)
    in

    Lwt.return (page (Network_list_page.html
      { proxy = proxy
          |> Option.map (Proxy.to_string ~hide_password:true)
      ; is_internet_connected
      ; services = showed_services
          |> List.map blur_service_proxy_password
      }))

  (** Helper to find a service by id *)
  let with_service ~connman id =
    let%lwt services = Connman.Manager.get_services connman in
    match List.find_opt (fun s -> s.Service.id = id) services with
    | Some s -> return s
    | None -> fail_with (Format.sprintf "Service does not exist (%s)" id)

  let details ~connman req =
    let service_id = param req "id" in
    let%lwt service = with_service connman service_id >|= blur_service_proxy_password in
    Lwt.return (page (Network_details_page.html service))

  (** Validate a proxy, fail if the proxy is given but invalid *)
  let with_empty_or_valid_proxy form_data =
    let proxy_str =
      form_data
      |> List.assoc "proxy"
      |> List.hd
    in
    if String.trim proxy_str = "" then
      return None
    else
      match Proxy.validate proxy_str with
      | Some proxy -> return (Some proxy)
      | None -> fail_with (Format.sprintf "'%s' is not a valid proxy. It should be in the form 'http://host:port' or 'http://user:password@host:port'." proxy_str)

  (** Connect to a service *)
  let connect ~(connman:Connman.Manager.t) req =
    let%lwt form_data = urlencoded_pairs_of_body req in
    let passphrase =
      match form_data |> List.assoc_opt "passphrase" with
      | Some [ passphrase ] ->
        Connman.Agent.Passphrase passphrase
      | _ ->
        Connman.Agent.None
    in
    let%lwt service = with_service ~connman (param req "id") in
    let%lwt proxy = with_empty_or_valid_proxy form_data in
    let%lwt () = Connman.Service.connect ~input:passphrase service in
    match proxy with
    | None ->
      (* Removing a proxy that would have been configured in the past *)
      let%lwt () = Connman.Service.set_direct_proxy service in
      Lwt.return (success (Format.sprintf "Connected with %s." service.name))
    | Some proxy ->
      let%lwt () = Connman.Service.set_manual_proxy service (Proxy.to_string ~hide_password:false proxy) in
      Lwt.return (success (Format.sprintf
        "Connected with %s and proxy '%s'."
        service.name
        (Proxy.to_string ~hide_password:true proxy)))

  (** Update the proxy of a service *)
  let update_proxy ~(connman:Connman.Manager.t) req =
    let%lwt form_data = urlencoded_pairs_of_body req in
    let%lwt service = with_service ~connman (param req "id") in
    match%lwt with_empty_or_valid_proxy form_data with
    | None ->
      fail_with "Proxy address may not be empty. Use the 'Disable proxy' button instead."
    | Some proxy ->
      let%lwt () = Connman.Service.set_manual_proxy service (Proxy.to_string ~hide_password:false proxy) in
      Lwt.return (success (Format.sprintf
        "Proxy of %s has been updated to '%s'."
        service.name
        (Proxy.to_string ~hide_password:true proxy)))

  (** Remove the proxy of a service *)
  let remove_proxy ~(connman:Connman.Manager.t) req =
    let%lwt service = with_service ~connman (param req "id") in
    let%lwt () = Connman.Service.set_direct_proxy service in
    Lwt.return (success (Format.sprintf "Proxy of %s has been disabled." service.name))

  (** Remove a service **)
  let remove ~(connman:Connman.Manager.t) req =
    let%lwt service = with_service ~connman (param req "id") in
    let%lwt () = Connman.Service.remove service in
    Lwt.return (success (Format.sprintf "Removed service %s." service.name))

  let build ~(connman:Connman.Manager.t) app =
    app
    |> get "/network" (overview ~connman)
    |> get "/network/:id" (details ~connman)
    |> post "/network/:id/connect" (connect ~connman)
    |> post "/network/:id/proxy/update" (update_proxy ~connman)
    |> post "/network/:id/proxy/remove" (remove_proxy ~connman)
    |> post "/network/:id/remove" (remove ~connman)

end


(** Label printing *)
module LabelGui = struct
  open Label_printer

  let make_label () =
    let%lwt ethernet_interfaces =
      Network.Interface.get_all ()
      >|= List.filter (fun (i: Network.Interface.t) ->
          Re.execp (Re.seq [Re.start; Re.str "enp" ] |> Re.compile) i.name)
    in
    let%lwt server_info = Info.get () in
    return
      ({ machine_id = server_info.machine_id
       ; mac_1 = CCOpt.(
             ethernet_interfaces
             |> CCList.get_at_idx 0
             >|= (fun i -> i.address)
             |> get_or ~default:"-"
           )
       ; mac_2 = CCOpt.(
             ethernet_interfaces
             |> CCList.get_at_idx 1
             >|= (fun i -> i.address)
             |> get_or ~default:"-"
           )
       } : Label_printer.label)

  let overview req =
    let%lwt label = make_label () in
    Lwt.return (page (Label_page.html label))

  let print req =
    let%lwt form_data = urlencoded_pairs_of_body req in
    let url = form_data
              |> List.assoc "label_printer_url"
              |> List.hd
    in
    let count = form_data
                |> List.assoc "count"
                |> List.hd
                |> int_of_string
    in
    let%lwt label = make_label () in
    CCList.replicate count ()
    |> Lwt_list.iter_s
      (fun () -> Label_printer.print ~url label)
    >|= (fun () -> "Labels printed.")
    >|= success

  let build app =
    app
    |> get "/label" overview
    |> post "/label/print" print

end

module StatusGui = struct
  let build ~health_s ~update_s ~rauc app =
    app
    |> get "/status" (fun req ->
        let%lwt rauc =
          catch
            (fun () -> Rauc.get_status rauc
              >|= Rauc.sexp_of_status
              >|= Sexplib.Sexp.to_string_hum)
            (fun exn -> Printexc.to_string exn
                        |> return)
        in
        let%lwt interfaces = Network.Interface.get_all () in
        Lwt.return (page (Status_page.html
          { health = health_s
              |> Lwt_react.S.value
              |> Health.sexp_of_state
              |> Sexplib.Sexp.to_string_hum
          ; update = update_s
              |> Lwt_react.S.value
              |> Update.sexp_of_state
              |> Sexplib.Sexp.to_string_hum
          ; rauc
          ; interfaces = interfaces
              |> [%sexp_of: Network.Interface.t list]
              |> Sexplib.Sexp.to_string_hum
          }))
      )
end

module ChangelogGui = struct
  let build app =
    app
    |> get "/changelog" (fun _ ->
        let%lwt changelog = Util.read_from_file log_src (resource_path (Fpath.v "Changelog.html")) in
        Lwt.return (page (Changelog_page.html changelog)))
end

module RemoteManagementGui = struct

  let rec wait_until_zerotier_is_on () =
    match%lwt Zerotier.get_status () with
    | Ok _ ->
        redirect' (Uri.of_string "/info")
    | Error _ ->
        let%lwt () = Lwt_unix.sleep 0.1 in
        wait_until_zerotier_is_on ()

  let build ~systemd app =
    app
    |> post "/remote-management/enable" (fun _ ->
        let%lwt () = Systemd.Manager.start_unit systemd "zerotierone.service" in
        with_timeout
          { duration = 2.0
          ; on_timeout = fun () ->
              let msg = "Timeout starting remote management service." in
              let%lwt () = Logs_lwt.err (fun m -> m "%s" msg) in
              Lwt.return (success msg)
          }
          wait_until_zerotier_is_on)

    |> post "/remote-management/disable" (fun _ ->
        let%lwt () = Systemd.Manager.stop_unit systemd "zerotierone.service" in
        redirect' (Uri.of_string "/info"))
end


let routes ~systemd ~shutdown ~health_s ~update_s ~rauc ~connman app =
  app
  |> middleware (static ())
  |> middleware error_handling

  |> get "/" (fun _ -> "/info" |> Uri.of_string |> redirect')

  |> get "/shutdown" (fun _ ->
      shutdown ()
      >|= (fun _ -> `String "Ok")
      >|= respond
    )

  |> InfoGui.build
  |> NetworkGui.build ~connman
  |> LocalizationGui.build
  |> LabelGui.build
  |> StatusGui.build ~health_s ~update_s ~rauc
  |> ChangelogGui.build
  |> RemoteManagementGui.build ~systemd

(* NOTE: probably easier to create a record with all the inputs instead of passing in x arguments. *)
let start ~port ~systemd ~shutdown ~health_s ~update_s ~rauc ~connman =
  empty
  |> Opium.App.port port
  |> routes ~systemd ~shutdown ~health_s ~update_s ~rauc ~connman
  |> start
