(** System health state *)
type state =
  | Pending
  | MarkingAsGood
  | Good
  | Bad of string
[@@deriving sexp]

(** Start system health monitor *)
val start :
     systemd:Systemd.Manager.t
  -> rauc:Rauc.t
  -> state Lwt_react.signal * unit Lwt.t
