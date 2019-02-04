open Lwt

type t =
  { app: string
  ; version: string
  ; machine_id: string
  ; zerotier_address: string option
  }

let to_json { app; version; machine_id; zerotier_address} =
  Ezjsonm.(
    dict [
      "app", string app
    ; "version", string version
    ; "machine_id", string machine_id
    ; "zerotier_address", match zerotier_address with
      | Some address -> string address
      | None -> string "—"
    ]
  )

(* TODO: get version from build system *)
let version =
  "2019.2.0-beta0"

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
  let%lwt zerotier_address =
    (match%lwt Zerotier.get_status () with
     | Ok status -> Some status.address |> return
     | Error _ -> None |> return
    )
  in
  let%lwt () = Lwt_io.close ic in
  { app = "PlayOS Controller"
  ; version
  ; machine_id
  ; zerotier_address
  }
  |> return

