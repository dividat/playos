open Lwt

let log_src = Logs.Src.create "locale"

let get_available_langs () =
  let lang_to_tuple j =
    let dict = Ezjsonm.get_dict j in
    ( dict |> List.assoc "locale" |> Ezjsonm.get_string
    , dict |> List.assoc "name" |> Ezjsonm.get_string
    )
  in
  let%lwt langs =
    Lwt.catch
      (fun () -> Util.read_from_file log_src "/etc/playos/languages.json")
      (fun _ -> Lwt.return "[]")
  in
  langs
  |> Ezjsonm.from_string
  |> Ezjsonm.value
  |> Ezjsonm.get_list lang_to_tuple
  |> Lwt.return

let get_lang () =
  (fun () -> Util.read_from_file log_src "/var/lib/gui-localization/lang")
  |> Lwt_result.catch
  >|= Base.Result.ok

let set_lang lang_code =
  Util.write_to_file log_src "/var/lib/gui-localization/lang" lang_code

let get_available_keymaps () =
  let keymap_to_tuple j =
    let dict = Ezjsonm.get_dict j in
    ( dict |> List.assoc "keymap" |> Ezjsonm.get_string
    , dict |> List.assoc "name" |> Ezjsonm.get_string
    )
  in
  let%lwt keymaps =
    Lwt.catch
      (fun () -> Util.read_from_file log_src "/etc/playos/keymaps.json")
      (fun _ -> Lwt.return "[]")
  in
  keymaps
  |> Ezjsonm.from_string
  |> Ezjsonm.value
  |> Ezjsonm.get_list keymap_to_tuple
  |> Lwt.return

let get_keymap () =
  (fun () -> Util.read_from_file log_src "/var/lib/gui-localization/keymap")
  |> Lwt_result.catch
  >|= Base.Result.ok

let set_keymap keymap_code =
  Util.write_to_file log_src "/var/lib/gui-localization/keymap" keymap_code
