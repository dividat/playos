open Rauc

let some_status : Rauc.Slot.status =
  {
    device = "Device";
    state = "Good";
    class' = "class";
    version = "0.0.0";
    installed_timestamp = "2023-01-01T00:00:00Z";
  }

module State = struct
  let rauc_status : Rauc.status ref = ref { a = some_status; b = some_status }
  let primary_slot = ref Slot.SystemA
  let booted_slot = ref Slot.SystemA
end

open State

let set_status slot status =
  match slot with
  | Slot.SystemA -> rauc_status := { !rauc_status with a = status }
  | Slot.SystemB -> rauc_status := { !rauc_status with b = status }

let get_status = !rauc_status |> Lwt.return

let set_primary slot = primary_slot := slot
let get_primary = Some Slot.SystemA |> Lwt.return

let set_booted_slot slot = booted_slot := slot
let get_booted_slot = Lwt.return Slot.SystemA

let extract_version bundle_path =
    (* TODO *)
    bundle_path

let install (bundle_path : string) : unit Lwt.t =
    let vsn = extract_version bundle_path in
    let%lwt booted_slot = get_booted_slot in
    let other_slot = match booted_slot with
        | Slot.SystemA -> Slot.SystemB
        | Slot.SystemB -> Slot.SystemA
    in
    (* "install" into non-booted slot *)
    let () = set_status other_slot {some_status with version = vsn} in
    let () = set_primary other_slot in
    (* TODO: what about mark_good? *)
    Lwt.return ()

let mark_good _ = failwith "Not implemented"
