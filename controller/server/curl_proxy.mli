(* tiny wrapper around Curl bindings with implicit
   proxy resolution *)
module type CurlProxyInterface = sig
    val request
      :  ?headers:(string * string) list
      -> ?data:string
      -> ?options:string list
      -> Uri.t
      -> Curl.result Lwt.t
end

(* Suggested interface after broader refactoring
   val init : unit -> (module CurlProxyInterface) Lwt.t
*)
val init : Connman.Manager.t -> (module CurlProxyInterface) Lwt.t
