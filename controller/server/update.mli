(* Compatible with Semver.t but also deriving sexp *)
type semver = int * int * int [@@deriving sexp]

(** Type containing version information.

    Versions are encoded with Semver decoding and a string representation. This is because the Semver library ignores pre-release and build meta-data.
    TODO: improve Semver library (see https://github.com/rgrinberg/ocaml-semver/issues/1)

*)
type version_info =
  {(* the latest available version *)
    latest : semver * string

  (* version of currently booted system *)
  ; booted : semver * string

  (* version of inactive system *)
  ; inactive : semver * string
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
[@@deriving sexp]

val start : rauc:Rauc.t -> update_url:string -> state Lwt_react.signal * unit Lwt.t
