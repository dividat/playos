(* HTTP Client for gettig updates and their metadata from
   the remote server. *)

module type S = sig
    (* download bundle version and return the file system path *)
    val download : string -> string Lwt.t

    (** Get latest version available *)
    val get_latest_version : unit -> string Lwt.t
end

module type UpdateClientDeps = sig
    val base_url: Uri.t
    val get_proxy: unit -> Uri.t option Lwt.t
end

val make_deps : (unit -> Uri.t option Lwt.t) -> Uri.t -> (module UpdateClientDeps)

module Make (DepsI : UpdateClientDeps) : S

(* Suggested interface after broader refactoring
   val init : unit -> (module S) Lwt.t
*)
val init : Connman.Manager.t -> (module S) Lwt.t
