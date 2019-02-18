open Lwt
open Sexplib.Std
open Opium_kernel.Rock

let of_file f =
  let%lwt ic = Lwt_io.(open_file ~mode:Lwt_io.Input) f in
  let%lwt template_f = Lwt_io.read ic in
  let%lwt () = Lwt_io.close ic in
  template_f
  |> Mustache.of_string
  |> return

let template name =
  let open Fpath in
  let template_dir =
    (Sys.argv.(0) |> v |> parent) / ".." / "share" / "template"
  in
  template_dir / (name ^ ".mustache")
  |> to_string
  |> of_file

let static () =
  (* Require the static content to be at a directory fixed to the binary location. This is not optimal, but works for the moment. TODO: figure out a better way to do this.
  *)
  let static_dir =
    Fpath.(
      (Sys.argv.(0) |> v |> parent) / ".." / "share" / "static"
      |> to_string
    )
  in
  Logs.debug (fun m -> m "static content dir: %s" static_dir);
  Opium.Middleware.static ~local_path:static_dir ~uri_prefix:"/static" ()

let index content =
  let%lwt template = template "index" in
  Mustache.render template
    (Ezjsonm.dict [
        "content", content |> Ezjsonm.string
      ])
  |> return

let success msg =
  msg
  |> index
  >|= Response.of_string_body

let info ~server_info () =
  let%lwt template = template "info" in
  Mustache.render template
    (Ezjsonm.dict [
        "server_info", server_info |> Info.to_json
      ])
  |> return

let network
    ~(connman:Connman.Manager.t)
    ~(internet:Network.Internet.state Lwt_react.S.t) =
  let open Connman in
  let%lwt template = template "network" in

  (* Check if internet connected *)
  let%lwt internet_connected =
    if
      internet
      |> Lwt_react.S.value
      |> Network.Internet.is_connected
    then
      return true
    else
      (* If not connected delay for 3 seconds.

         Motivation: Add a delay after connecting to a new service.
      *)
      let%lwt () = Lwt_unix.sleep 3.0 in
      internet
      |> Lwt_react.S.value
      |> Network.Internet.is_connected
      |> return
  in

  let%lwt services =
    Manager.get_services connman
    (* If not connected show all services, otherwise show services that are connected *)
    >|= List.filter (fun s -> not internet_connected || s |> Connman.Service.is_connected)
  in

  let%lwt interfaces = Network.Interface.get_all () in

  Mustache.render template
    (Ezjsonm.dict [
        "internet_connected", internet_connected |> Ezjsonm.bool
      ; "services", services |> Ezjsonm.list (fun s -> s |> Service.to_json |> Ezjsonm.value)
      ; "interfaces", interfaces |> Ezjsonm.list (Network.Interface.to_json)
      ])
  |> return

let find_service ~connman id =
  let open Connman in
  Connman.Manager.get_services connman
  >|= List.find_opt (fun (s:Service.t) -> s.id = id)

let network_service_connect
    ~(connman:Connman.Manager.t)
    req =
  let open Opium.App in
  let service_id = param req "id" in
  let%lwt form_data =
    urlencoded_pairs_of_body req
  in
  let input =
    match form_data |> List.assoc_opt "passphrase" with
    | Some [ passphrase ] ->
      Connman.Agent.Passphrase passphrase
    | _ ->
      Connman.Agent.None
  in
  match%lwt find_service ~connman service_id with
  | None ->
    fail_with (Format.sprintf "Service does not exist (%s)" service_id)
  | Some service ->
    Connman.Service.connect ~input service
    >|= (fun () -> Format.sprintf "Connected with %s." service.name)
    >>= success

let network_service_remove
    ~(connman:Connman.Manager.t)
    req =
  let open Opium.App in
  let service_id = param req "id" in
  match%lwt find_service ~connman service_id with
  | None ->
    fail_with (Format.sprintf "Service does not exist (%s)" service_id)
  | Some service ->
    Connman.Service.remove service
    >|= (fun () -> Format.sprintf "Removed service %s." service.name)
    >>= success

let get_label () =
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

let label req =
  let%lwt template = template "label" in

  let%lwt label = get_label () in

  Mustache.render template
    Ezjsonm.(dict [
        "machine_id", label.machine_id |> string
      ; "mac_1", label.mac_1 |> string
      ; "mac_2", label.mac_2 |> string
      ; "default_label_printer_url", "http://pinocchio.local:3000/play-computer" |> string
      ])
  |> return

let label_print req =
  let open Opium.App in
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
  let%lwt label = get_label () in
  CCList.replicate count ()
  |> Lwt_list.iter_s
    (fun () -> Label_printer.print ~url label)
  >|= (fun () -> "Labels printed.")
  >>= success

let error_handling =
  let open Opium_kernel.Rock in
  let filter handler req =
    match%lwt handler req |> Lwt_result.catch with
    | Ok res ->
      return res
    | Error exn ->
      let%lwt template = template "error" in
      Mustache.render template
        Ezjsonm.(dict [
            "exn", exn
                   |> Sexplib.Std.sexp_of_exn
                   |> Sexplib.Sexp.to_string_hum
                   |> string
          ; "request", req
                       |> Request.sexp_of_t
                       |> Sexplib.Sexp.to_string_hum
                       |> string
          ])
      |> index
      >|= Response.of_string_body
  in
  Middleware.create ~name:"Error" ~filter

let routes ~connman ~internet app =
  let open Opium.App in
  app
  |> middleware (static ())
  |> middleware error_handling
  |> get "/gui" (fun _ -> "/gui/info" |> Uri.of_string |> redirect')
  |> get "/gui/info" (fun _ ->
      let%lwt server_info = Info.get () in
      info ~server_info ()
      >>= index
      >|= Response.of_string_body)

  |> get "/gui/network" (fun _ ->
      let%lwt server_info = Info.get () in
      network ~connman ~internet
      >>= index
      >|= Response.of_string_body
    )

  |> get "/gui/network/:id" (fun req ->
      "/gui/network" |> Uri.of_string |> redirect'
    )

  |> post "/gui/network/:id/connect" (network_service_connect ~connman)
  |> post "/gui/network/:id/remove" (network_service_remove ~connman)

  |> get "/gui/label" (fun req ->
      label req
      >>= index
      >|= Response.of_string_body
    )
  |> post "/gui/label/print" label_print

