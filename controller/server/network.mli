(** Initialize Network connectivity *)
val init : systemd : Systemd.Manager.t
  -> connman : Connman.Manager.t
  -> (unit,exn) Lwt_result.t

module Internet : sig
  (** Internet connectivity state *)
  type state =
    | Pending
    | Connected
    | NotConnected of string
  [@@deriving sexp]

  val is_connected : state -> bool

  (** [get connman] starts a thread that checks Internet connectivity periodically and on changes to network (changes in ConnMan services).

      The state of internet connectivity is made available via a signal.
  *)
  val get: connman:Connman.Manager.t -> (state Lwt_react.S.t * unit Lwt.t) Lwt.t

end

module Interface : sig
  (** Network interface *)
  type t =
    { index: int
    ; name: string
    ; address: string
    ; link_type: string
    }
  [@@deriving sexp]

  val to_json : t -> Ezjsonm.value

  (** Get all available interfaces.

      This uses the Linux `ip` utility.
  *)
  val get_all : unit -> t list Lwt.t

end
