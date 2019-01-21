open Lwt

let version =
  "2019.1.0-dev"

module Server_info = struct
  type t =
    { app: string
    ; version: string }

  let to_json { app; version } =
    Ezjsonm.(
      dict [
        "app", string app
      ; "version", string version
      ]
    )
end

let server_info: Server_info.t =
  { app = "PlayOS Controller"
  ; version = version}


let gui =
  let open Tyxml.Html in
  let html_to_string tyxml = Format.asprintf "%a" (pp ()) tyxml in
  let client_script =
    script ~a:[a_src (Xml.uri_of_string "/static/client.js")] (pcdata "")
  in
  html
    (head ("PlayOS Controller" |> pcdata |> title) [
        link ~rel:[`Stylesheet] ~href:"/static/style.css" ()
      ])
    (body [
        (server_info |> Server_info.to_json |> Ezjsonm.to_string |> pcdata)
      ; client_script
      ])
  |> html_to_string


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

let server ~(rauc:Rauc.t) =
  Opium.App.(
    empty
    |> port 3333
    |> get "/" (fun _ -> `Json (server_info |> Server_info.to_json) |> respond')
    |> get "/rauc" (fun _ ->
        Rauc.get_status rauc
        >|= Rauc.json_of_status
        >|= (fun x -> `Json x)
        >|= respond
      )
    |> get "/gui" (fun _ -> `Html gui |> respond')
    |> middleware (static ())
    |> middleware (Opium.Middleware.debug)
  )

let update_url =
  "http://192.168.122.1:9999/"

let main () =
  Logs.set_reporter (Logging.reporter ());
  Logs.set_level (Some Logs.Debug);

  let%lwt () = Logs_lwt.info (fun m -> m "PlayOS Controller Daemon (%s) starting up" version) in

  (* Connect with RAUC *)
  let%lwt rauc = Rauc.daemon () in

  (* Mark currently booted slot as "good" *)
  let%lwt () = try%lwt
      Rauc.get_booted_slot rauc
      >>= Rauc.mark_good rauc
    with
    | exn ->
      Logs_lwt.err (fun m -> m "RAUC: %s" (Printexc.to_string exn))
  in

  let%lwt () = try%lwt
      Rauc.get_status rauc
      >|= Rauc.sexp_of_status
      >|= Sexplib.Sexp.to_string_hum
      >>= Lwt_io.printl
    with
    | exn ->
      Logs_lwt.err (fun m -> m "RAUC: %s" (Printexc.to_string exn))
  in

  (* All following promises should run forever. *)
  let%lwt () =
    Lwt.pick [
      server rauc |> Opium.App.start
    ; Update.start rauc update_url
    ]
  in

  Logs_lwt.info (fun m -> m "terminating")

let () =
  Lwt_main.run (main ())
