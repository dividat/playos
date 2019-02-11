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
  val get: Connman.Manager.t -> (state Lwt_react.S.t * unit Lwt.t) Lwt.t

end
