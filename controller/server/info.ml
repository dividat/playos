open Lwt

type t =
  { app: string
  ; version: string
  ; machine_id: string
  }

let to_json { app; version; machine_id } =
  Ezjsonm.(
    dict [
      "app", string app
    ; "version", string version
    ; "machine_id", string machine_id
    ]
  )

let version =
  "2019.1.0-dev"

let of_file f =
  let%lwt ic = Lwt_io.(open_file ~mode:Lwt_io.Input) f in
  let%lwt template_f = Lwt_io.read ic in
  let%lwt () = Lwt_io.close ic in
  template_f
  |> Mustache.of_string
  |> return

let get () =
  let%lwt ic = "/etc/machine-id" |> Lwt_io.(open_file ~mode:Input) in
  let%lwt machine_id = Lwt_io.read ic in
  let%lwt () = Lwt_io.close ic in
  { app = "PlayOS Controller"
  ; version = version
  ; machine_id = machine_id}
  |> return

