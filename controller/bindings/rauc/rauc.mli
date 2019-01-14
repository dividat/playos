(** [daemon ()] returns the peer object for the RAUC service/daemon *)
val daemon : unit -> OBus_peer.Private.t Lwt.t

module Slot : sig
  (** Currently booted slot *)
  val current_boot_slot : OBus_peer.Private.t -> string Lwt.t

  (** Mark the currently booted slot as good. *)
  val mark_current_good : OBus_peer.Private.t -> (string * string) Lwt.t
end

