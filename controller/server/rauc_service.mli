(* would suggest moving this to `rauc_service_intf.ml` and 
   using `include`s (jane-street-style) to avoid having to duplicate
   it in the .ml files *)
module type RaucServiceIntf = sig
    (** [get_status rauc] returns current RAUC status *)
    val get_status : unit -> Rauc.status Lwt.t

    (** [get_booted_slot rauc] returns the currently booted slot *)
    val get_booted_slot : unit -> Rauc.Slot.t Lwt.t

    (** [mark_good rauc slot] marks the slot [slot] as good *)
    val mark_good : Rauc.Slot.t -> unit Lwt.t

    (** [get_primary rauc] returns current primary slot, if any *)
    val get_primary : unit -> Rauc.Slot.t option Lwt.t

    (** [install rauc source] install the bundle at path [source] *)
    val install : string -> unit Lwt.t
end

val init : unit -> (module RaucServiceIntf) Lwt.t

(* NOTE: only exposed now to enable partial refactoring. In the final impl only
   `init` is called once at the top-level (server module) and then the
   module/interface is passed to dependencies (Update, Gui, Health) directly *)
val build_module : Rauc.t -> (module RaucServiceIntf)
