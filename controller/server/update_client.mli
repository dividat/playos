(* HTTP Client for gettig updates and their metadata from
   the remote server. *)

type version = string
type bundle_path = string
type version_pair = (Semver.t [@sexp.opaque]) * string

val semver_of_string : string -> version_pair
val latest_download_url : update_url:string -> string -> string

module type UpdateClientIntf = sig
    (* drop the URL string part - only need version *)
    val download : Uri.t -> version -> bundle_path Lwt.t

    (** Get latest version available at [url] *)
    val get_latest_version : unit -> version_pair Lwt.t

end

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
   val init : unit -> (module UpdateClientIntf) Lwt.t
*)
val init : Connman.Manager.t -> (module UpdateClientIntf) Lwt.t

val build_module : (module CurlProxyInterface) -> (module UpdateClientIntf )
