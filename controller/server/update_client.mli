(* HTTP Client for gettig updates and their metadata from
   the remote server. *)

(* unparsed semver version *)
type version = string
(* local filesystem path *)
type bundle_path = string

module type S = sig
    (* download bundle [version] to [bundle_path] *)
    val download : version -> bundle_path Lwt.t

    (** Get latest version available *)
    val get_latest_version : unit -> version Lwt.t
end

module type UpdateClientDeps = sig
    (* TODO: convert to Uri.t *)
    val base_url: string
    val get_proxy: unit -> Uri.t option Lwt.t
end

val make_deps : (unit -> Uri.t option Lwt.t) -> string -> (module UpdateClientDeps)

module Make (DepsI : UpdateClientDeps) : S

(* Suggested interface after broader refactoring
   val init : unit -> (module S) Lwt.t
*)
val init : Connman.Manager.t -> (module S) Lwt.t
