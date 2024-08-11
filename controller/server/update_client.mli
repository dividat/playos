(* HTTP Client for gettig updates and their metadata from
   the remote server. *)

(* unparsed semver version *)
type version = string
(* local filesystem path *)
type bundle_path = string

module type UpdateClientIntf = sig
    (* TODO: this method is currently overspecified, it should probably
       provide only the version and the client should resolve the URL *)
    (* download bundle from specified url and save it as `version` *)
    val download : Uri.t -> version -> bundle_path Lwt.t

    (* URL from which the specified version would be downloaded *)
    val download_url : version -> Uri.t

    (** Get latest version available at [url] *)
    val get_latest_version : unit -> version Lwt.t
end

module type UpdateClientConfig = sig
    (* TODO: convert to Uri.t *)
    val base_url: string
    val proxy: Uri.t option
end

val make_config : ?proxy:Uri.t -> string -> (module UpdateClientConfig)

module Make (ConfigI : UpdateClientConfig) : UpdateClientIntf

(* Suggested interface after broader refactoring
   val init : unit -> (module UpdateClientIntf) Lwt.t
*)
val init : Connman.Manager.t -> (module UpdateClientIntf) Lwt.t
