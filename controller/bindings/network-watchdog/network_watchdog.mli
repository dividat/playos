(* Tiny interface for enabling/disabling the PlayOS network watchdog *)

val is_disabled : Systemd.Manager.t -> bool Lwt.t

val enable : Systemd.Manager.t -> unit Lwt.t

val disable : Systemd.Manager.t -> unit Lwt.t
