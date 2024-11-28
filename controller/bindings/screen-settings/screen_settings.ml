open Lwt

let log_src = Logs.Src.create "screen-scaling"

let settings_file = "/var/lib/gui-localization/screen-scaling"

(* Scaling options *)
type scaling =
  (* No config file
     xsession script decides behaviour
  *)
  | Default
  (* Config file with keyword: "full-hd"
     Explicitly opt-in to scaling to FullHD
  *)
  | FullHD
  (* Config file with keyword: "native"
     Explicitly opt-out of scaling to FullHD
  *)
  | Native

let scaling_of_string = function
  | "default" ->
      Some Default
  | "full-hd" ->
      Some FullHD
  | "native" ->
      Some Native
  | _ ->
      None

let string_of_scaling = function
  | Default ->
      "default"
  | FullHD ->
      "full-hd"
  | Native ->
      "native"

(* Used for representing options in the UI, ie. in dropdown. *)
let label_of_scaling = function
  | Default ->
      "Default"
  | FullHD ->
      "Full HD"
  | Native ->
      "Native"

let set_scaling scaling =
  match scaling with
  | Default ->
      Lwt_unix.file_exists settings_file
      >>= fun exists ->
      if exists then Lwt_unix.unlink settings_file else return ()
  | _ ->
      Util.write_to_file log_src settings_file (string_of_scaling scaling)

let get_scaling () =
  Lwt_unix.file_exists settings_file
  >>= fun exists ->
  if exists then
    Util.read_from_file log_src settings_file
    >|= fun s -> s |> scaling_of_string |> Option.value ~default:Default
  else return Default
