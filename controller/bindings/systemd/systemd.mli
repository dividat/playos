(** Systemd bindings *)

module Unit : sig
  type t
end

module Manager : sig

  type t

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

  (** [get_unit t name] returns the unit [name] *)
  val get_unit : t -> string -> Unit.t Lwt.t

  (** [restart_unit t name] a unit with name [name].

      Example:

        restart_unit t "connman.service"

  *)
  val restart_unit : t -> string -> unit Lwt.t

  (** [start_unit t name] a unit with name [name].

      Example:

        start_unit t "zerotierone.service"

   *)
  val start_unit : t -> string -> unit Lwt.t

  (** [stop_unit t name] a unit with name [name].

      Example:

        stop_unit t "zerotierone.service"

   *)
  val stop_unit : t -> string -> unit Lwt.t

end
