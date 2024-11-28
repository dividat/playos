(* HTTP Client for gettig updates and their metadata from
   the remote server. *)

module type S = sig
  (* download bundle version and return the file system path *)
  val download : string -> string Lwt.t

  (** Get latest version available *)
  val get_latest_version : unit -> string Lwt.t
end

module type UpdateClientDeps = sig
  val base_url : Uri.t

  val download_dir : string

  val get_proxy : unit -> Uri.t option Lwt.t
end

val make_deps :
     ?download_dir:string
  -> (unit -> Uri.t option Lwt.t)
  -> Uri.t
  -> (module UpdateClientDeps)

module Make (_ : UpdateClientDeps) : S

val build_module : Connman.Manager.t -> (module S)
