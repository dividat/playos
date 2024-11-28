(** Type containing version information. *)
type version_info =
  { (* the latest available version *)
    latest : Semver.t (* version of currently booted system *)
  ; booted : Semver.t (* version of inactive system *)
  ; inactive : Semver.t
  }
[@@deriving sexp_of]

type update_error =
  | ErrorGettingVersionInfo of string
  | ErrorDownloading of string
  | ErrorInstalling of string
[@@deriving sexp_of]

type system_status =
  | UpToDate
  | NeedsUpdate
  | RebootRequired
  | OutOfDateVersionSelected
  | ReinstallRequired
  | UpdateError of update_error
[@@deriving sexp_of]

type sleep_duration = float (* seconds *) [@@deriving sexp_of]

(** State of update mechanism *)
type process_state =
  | Sleeping of sleep_duration
  | GettingVersionInfo
  | Downloading of string
  | Installing of string
[@@deriving sexp_of]

type state =
  { version_info : version_info option
  ; system_status : system_status
  ; process_state : process_state
  }
[@@deriving sexp_of]

type config =
  { (* time to sleep in seconds until retrying after a (Curl/HTTP) error *)
    error_backoff_duration : sleep_duration
  ; (* time to sleep in seconds between checking for available updates *)
    check_for_updates_interval : sleep_duration
  }

module type ServiceDeps = sig
  module ClientI : Update_client.S

  module RaucI : Rauc_service.S

  val config : config
end

(* exposed for unit testing purposes *)
val initial_state : state

module type UpdateService = sig
  val run : (state -> unit) -> unit Lwt.t

  (* exposed for unit testing purposes *)
  val run_step : state -> state Lwt.t
end

module Make (_ : ServiceDeps) : UpdateService

(* top-level entrypoint that uses global Config.System and initializes
   all the dependencies *)
val start :
     connman:Connman.Manager.t
  -> rauc:Rauc.t
  -> state Lwt_react.signal * unit Lwt.t
