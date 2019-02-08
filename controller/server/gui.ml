open Lwt
open Sexplib.Std

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


let respond_html x =
  let open Opium.App in
  `Html x |> respond

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
  let internet_connected =
    internet
    |> Lwt_react.S.value
    |> Network.Internet.is_connected
  in
  let%lwt services =
    (* Only display available services if not connected. *)
    if internet_connected then
      return []
    else
      Manager.get_services connman
  in
  Mustache.render template
    (Ezjsonm.dict [
        "internet_connected", internet_connected |> Ezjsonm.bool
      ; "services", services |> Ezjsonm.list (fun s -> s |> Service.to_json |> Ezjsonm.value)
      ])
  |> return

let find_service ~connman id =
  let open Connman in
  Connman.Manager.get_services connman
  >|= List.find_opt (fun (s:Service.t) -> s.id = id)

let network_service
    ~(connman:Connman.Manager.t)
    service_id =
  let open Connman in
  let open Opium.App in
  let%lwt template = template "network_service" in
  match%lwt find_service ~connman service_id with
  | None ->
    "/gui/network" |> Uri.of_string |> redirect'
  | Some service ->
    begin
      Mustache.render template
        (Ezjsonm.dict [
            "service", service |> Service.to_json |> Ezjsonm.value
          ])
      |> index
      >|= respond_html
    end

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
  let%lwt () =
    match%lwt find_service ~connman service_id with
    | None ->
      return_unit
    | Some service ->
      Connman.Service.connect ~input service
  in
  "/gui/network" |> Uri.of_string |> redirect'

let routes ~connman ~internet app =
  let open Opium.App in
  app
  |> middleware (static ())
  |> get "/gui" (fun _ -> "/gui/info" |> Uri.of_string |> redirect')
  |> get "/gui/info" (fun _ ->
      let%lwt server_info = Info.get () in
      info ~server_info ()
      >>= index
      >|= respond_html)

  |> get "/gui/network" (fun _ ->
      let%lwt server_info = Info.get () in
      network ~connman ~internet
      >>= index
      >|= respond_html
    )

  |> get "/gui/network/:id" (fun req ->
      let service_id = param req "id" in
      network_service ~connman service_id
    )

  |> post "/gui/network/:id/connect" (network_service_connect ~connman)


