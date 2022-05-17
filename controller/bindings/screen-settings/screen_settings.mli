
type scaling =
  | Default
  | Scaled
  | Native

val string_of_scaling : scaling -> string
val label_of_scaling : scaling -> string
val scaling_of_string : string -> scaling option

val get_scaling : unit -> scaling Lwt.t
val set_scaling : scaling -> unit Lwt.t
