module type S = sig
    (** [get_status unit] returns current RAUC status *)
    val get_status : unit -> Rauc.status Lwt.t

    (** [get_booted_slot unit] returns the currently booted slot *)
    val get_booted_slot : unit -> Rauc.Slot.t Lwt.t

    (** [mark_good slot] marks the slot [slot] as good *)
    val mark_good : Rauc.Slot.t -> unit Lwt.t

    (** [get_primary unit] returns current primary slot, if any *)
    val get_primary : unit -> Rauc.Slot.t option Lwt.t

    (** [install source] install the bundle at path [source] *)
    val install : string -> unit Lwt.t
end

val build_module : Rauc.t -> (module S)
