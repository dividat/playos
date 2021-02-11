open Lwt

let log_src = Logs.Src.create "locale"

let get_lang () =
  Util.read_from_file log_src "/var/lib/gui-localization/lang"
  |> Lwt_result.catch
  >|= Base.Result.ok

let set_lang lang_code =
  Util.write_to_file log_src "/var/lib/gui-localization/lang" lang_code

let get_keymap () =
  Util.read_from_file log_src "/var/lib/gui-localization/keymap"
  |> Lwt_result.catch
  >|= Base.Result.ok

let set_keymap keymap_code =
  Util.write_to_file log_src "/var/lib/gui-localization/keymap" keymap_code
