open Lwt

type t =
  { app: string
  ; version: string
  ; update_url : string
  ; kiosk_url : string
  ; machine_id: string
  ; zerotier_address: string option
  ; local_time : string
  }

let to_json { app; version; update_url; kiosk_url; machine_id; zerotier_address; local_time } =
  Ezjsonm.(
    dict [
      "app", string app
    ; "version", string version
    ; "update_url", string update_url
    ; "kiosk_url", string kiosk_url
    ; "machine_id", string machine_id
    ; "zerotier_address", (match zerotier_address with
      | Some address -> string address
      | None -> string "—"
    )
    ; "local_time", string local_time
    ]
  )

(** Version, set by build system *)
let version =
  "@PLAYOS_VERSION@"

(** URL from where to get updates, set by build system *)
let update_url =
  "@PLAYOS_UPDATE_URL@"

(** URL to which kiosk is pointed *)
let kiosk_url =
  "@PLAYOS_KIOSK_URL@"

let of_file f =
  let%lwt ic = Lwt_io.(open_file ~mode:Lwt_io.Input) f in
  let%lwt template_f = Lwt_io.read ic in
  let%lwt () = Lwt_io.close ic in
  template_f
  |> Mustache.of_string
  |> return

let get () =
  let%lwt ic = "/etc/machine-id" |> Lwt_io.(open_file ~mode:Input) in
  let%lwt machine_id = Lwt_io.read ic >|= String.trim in
  let%lwt zerotier_address =
    (match%lwt Zerotier.get_status () with
     | Ok status -> Some status.address |> return
     | Error _ -> None |> return
    )
  in
  let%lwt timedate_daemon = Timedate.daemon () in
  let%lwt current_time = Timedate.get_current_time timedate_daemon in
  let%lwt timezone =
    (match%lwt Timedate.get_timezone timedate_daemon with
     | Some tz -> return tz
     | None -> return "No timezone"
    )
  in
  let local_time = current_time ^ " (" ^ timezone ^ ")" in
  let%lwt () = Lwt_io.close ic in
  { app = "PlayOS Controller"
  ; version
  ; update_url
  ; kiosk_url
  ; machine_id
  ; zerotier_address
  ; local_time
  }
  |> return

