(** Type containing version information.
*)
type version_info =
  {(* the latest available version *)
    latest : Semver.t * string

  (* version of currently booted system *)
  ; booted : Semver.t * string

  (* version of inactive system *)
  ; inactive : Semver.t * string
  }
[@@deriving sexp]

(** State of update mechanism *)
type state =
  | GettingVersionInfo
  | ErrorGettingVersionInfo of string
  | UpToDate of version_info
  | Downloading of {url: string; version: string}
  | ErrorDownloading of string
  | Installing of string
  | ErrorInstalling of string
  | RebootRequired
  | OutOfDateVersionSelected
  | ReinstallRequired
[@@deriving sexp]

type sleep_duration = float (* seconds *)

type config = {
    (* time to sleep in seconds until retrying after a (Curl/HTTP) error *)
    error_backoff_duration: sleep_duration;

    (* time to sleep in seconds between checking for available updates *)
    check_for_updates_interval: sleep_duration;

    (* where to fetch updates from *)
    update_url: string
}

module type ServiceDeps = sig
    module CurlI: Curl_proxy.CurlProxyInterface
    module RaucI: Rauc_service.RaucServiceIntf
    val config : config
end

module UpdateService : functor (_ : ServiceDeps) -> sig
  val run : set_state:(state -> unit) -> state -> unit Lwt.t

  (* private functions used in testing *)
  module Private : sig
    val run_step : state -> state Lwt.t
  end
end

(* maintaining the original entrypoint for backwards compatibility *)
val start : connman:Connman.Manager.t -> rauc:Rauc.t -> update_url:string -> state Lwt_react.signal * unit Lwt.t
