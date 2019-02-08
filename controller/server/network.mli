module Internet : sig
  (** Internet connectivity state *)
  type state =
    | Connected
    | NotConnected of string
  [@@deriving sexp]

  val is_connected : state -> bool

  (** [get_state connman] returns signal carrying state.

      State is updated on changes in ConnMan services.

      TODO: periodically check state (regardless of ConnMan services).
  *)
  val get_state : Connman.Manager.t -> state Lwt_react.S.t Lwt.t

end
