open Lwt

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

let info () =
  let%lwt template = template "info" in
  Mustache.render template
    (Ezjsonm.dict [
        "server_info", Info.(get () |> to_json)
      ])
  |> return

let index content =
  let%lwt template = template "index" in
  Mustache.render template
    (Ezjsonm.dict [
        "server_info", Info.(get () |> to_json)
      ; "content", content |> Ezjsonm.string
      ])
  |> return

let routes app =
  let open Opium.App in
  let respond_html x = `Html x |> respond in
  app
  |> middleware (static ())
  |> get "/gui" (fun _ -> "/gui/info" |> Uri.of_string |> redirect')
  |> get "/gui/info" (fun _ -> info () >>= index >|= respond_html)


