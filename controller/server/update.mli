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

val start : rauc:Rauc.t -> update_url:string -> state Lwt_react.signal * unit Lwt.t
