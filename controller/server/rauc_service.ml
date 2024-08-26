module type RaucServiceIntf = sig
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

module RaucOBus(OBusRef: sig val peer: Rauc.t end): RaucServiceIntf = struct
    let t = OBusRef.peer

    let get_status () : Rauc.status Lwt.t =
        let () = Printf.printf "%s" "Getting status" in
        Rauc.get_status t

    let get_booted_slot () : Rauc.Slot.t Lwt.t =
        Rauc.get_booted_slot t

    let mark_good = Rauc.mark_good t

    let get_primary () : Rauc.Slot.t option Lwt.t =
        Rauc.get_primary t

    let install : string -> unit Lwt.t =
        Rauc.install t
end

let build_module rauc_peer : (module RaucServiceIntf) =
  (module RaucOBus (struct let peer = rauc_peer end))

let init () =
  (* Connect with RAUC *)
  let%lwt rauc_peer = Rauc.daemon () in
  Lwt.return @@ build_module rauc_peer
