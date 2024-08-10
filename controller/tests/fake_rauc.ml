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
  let primary_slot : Rauc.Slot.t option ref = ref None
  let booted_slot = ref Slot.SystemA
end

open State

let set_status slot status =
  match slot with
  | Slot.SystemA -> rauc_status := { !rauc_status with a = status }
  | Slot.SystemB -> rauc_status := { !rauc_status with b = status }

let get_status () = !rauc_status |> Lwt.return

let get_slot_status slot =
  match slot with
  | Slot.SystemA -> !rauc_status.a
  | Slot.SystemB -> !rauc_status.b

let set_primary slot = primary_slot := Some slot
let get_primary () = !primary_slot |> Lwt.return

let set_booted_slot slot = booted_slot := slot
let get_booted_slot () = Lwt.return Slot.SystemA

let extract_version bundle_path =
    let regex_str = {|.*-\([0-9]+\.[0-9]+\.[0-9]+.*\)\.raucb|} in
    let regex = Str.regexp regex_str in
    let m = Str.string_match regex bundle_path 0 in
    if m then
        Str.matched_group 1 bundle_path
    else
        Alcotest.fail @@
            "Failed to extract version from bundle_path: " ^ bundle_path

let install (bundle_path : string) : unit Lwt.t =
    let vsn = extract_version bundle_path in
    let%lwt booted_slot = get_booted_slot () in
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
