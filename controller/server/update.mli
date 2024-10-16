(** Type containing version information.
*)
type version_info =
  {(* the latest available version *)
    latest : Semver.t

  (* version of currently booted system *)
  ; booted : Semver.t

  (* version of inactive system *)
  ; inactive : Semver.t
  }
[@@deriving sexp_of]

(** State of update mechanism *)
type state =
  | GettingVersionInfo
  | ErrorGettingVersionInfo of string
  | UpToDate of version_info
  | Downloading of string
  | ErrorDownloading of string
  | Installing of string
  | ErrorInstalling of string
  | RebootRequired
  | OutOfDateVersionSelected
  | ReinstallRequired
[@@deriving sexp_of]

type sleep_duration = float (* seconds *)

type config = {
    (* time to sleep in seconds until retrying after a (Curl/HTTP) error *)
    error_backoff_duration: sleep_duration;

    (* time to sleep in seconds between checking for available updates *)
    check_for_updates_interval: sleep_duration;
}

module type ServiceDeps = sig
    module ClientI: Update_client.S
    module RaucI: Rauc_service.S
    val config : config
end

module type UpdateService = sig
  val run : set_state:(state -> unit) -> state -> unit Lwt.t

  val run_step : state -> state Lwt.t
end

module Make (_ : ServiceDeps) : UpdateService

(* top-level entrypoint that uses global Config.System and initializes
   all the dependencies *)
val start : connman:Connman.Manager.t -> rauc:Rauc.t -> state Lwt_react.signal * unit Lwt.t
