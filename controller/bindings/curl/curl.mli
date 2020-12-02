type error =
  | UnsuccessfulStatus of int * string
  | UnreadableStatus of string
  | ProcessExit of int * string
  | ProcessKill of int
  | ProcessStop of int

type result =
  | RequestSuccess of int * string
  | RequestFailure of error

val pretty_print_error : error -> string

val request
  :  ?proxy:Proxy.t
  -> ?headers:(string * string) list
  -> ?data:string
  -> ?options:string list
  -> Uri.t
  -> result Lwt.t
