type t = OBus_peer.Private.t

(** [daemon ()] returns the peer object for the RAUC service/daemon *)
val daemon : unit -> t Lwt.t

module Slot : sig

  type t =
    | SystemA
    | SystemB

  type status =
    { device : string
    ; class' : string
    ; state : string
    (* Fields that are only available when installed via RAUC (not from installer script)*)
    ; version : string
    ; installed_timestamp : string
    }
  [@@deriving sexp]

end

(** [get_booted_slot rauc] returns the currently booted slot *)
val get_booted_slot : t -> Slot.t Lwt.t

(** [mark_good rauc slot] marks the slot [slot] as good*)
val mark_good : t -> Slot.t -> unit Lwt.t

(** Rauc status *)
type status =
  { a: Slot.status
  ; b: Slot.status
  }
[@@deriving sexp]

(** Encode status as json *)
val json_of_status : status -> Ezjsonm.t

(** [get_status rauc] returns current RAUC status *)
val get_status : t -> status Lwt.t
