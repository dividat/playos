(** Systemd bindings *)


module Manager : sig

  type t = OBus_proxy.t

  (** connect with systemd D-Bus API *)
  val connect : unit -> t Lwt.t

  (** System state *)
  type system_state =
    | Initializing
    | Starting
    | Running
    | Degraded
    | Maintenance
    | Stopping
    | Offline
    | Unknown
  [@@deriving sexp]

  (** [get_system_state t] returns the system state *)
  val get_system_state : t -> system_state Lwt.t

end
