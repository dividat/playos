(* Tiny interface for enabling/disabling the PlayOS network watchdog *)

val is_disabled : unit -> bool Lwt.t

val enable : Systemd.Manager.t -> unit Lwt.t

val disable : Systemd.Manager.t -> unit Lwt.t
