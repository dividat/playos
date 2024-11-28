val get_lang : unit -> string option Lwt.t

val set_lang : string -> unit Lwt.t

val get_keymap : unit -> string option Lwt.t

val set_keymap : string -> unit Lwt.t
