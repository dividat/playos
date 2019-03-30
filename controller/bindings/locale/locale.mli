val get_lang : unit -> (string option) Lwt.t
val set_lang : string -> bool Lwt.t

val get_keymap : unit -> (string option) Lwt.t
val set_keymap : string -> bool Lwt.t
