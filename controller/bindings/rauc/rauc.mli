open OBus_peer.Private

(** [daemon ()] returns the peer object for the RAUC service/daemon *)
val daemon : unit -> t Lwt.t

module Slot : sig

  type t =
    | SystemA
    | SystemB

end


val get_booted_slot : t -> Slot.t Lwt.t

val mark_good : t -> Slot.t -> unit Lwt.t

val get_slot_status : t -> ( string * (string * OBus_value.V.single) list ) list Lwt.t
