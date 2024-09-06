open Update
open Lwt
open Update_test_helpers

let both_out_of_date {update_client; rauc} =
  let init_state = GettingVersionInfo in
  (* Swap versions to make sure both versions are compared *)
  let booted_version = "10.0.0" in
  let inactive_version = "9.0.0" in
  let upstream_version = "10.0.2" in

  let expected_bundle_name vsn =
      Mock_update_client.test_bundle_name ^ _MAGIC_PAT ^ vsn ^ _MAGIC_PAT
  in

  let expected_state_sequence =
    [
      UpdateMock (fun () ->
        (* TODO: test for symmetry by swapping A and B *)
        rauc#set_version SystemA booted_version;
        rauc#set_version SystemB inactive_version;
        rauc#set_booted_slot SystemA;

        update_client#add_bundle upstream_version
            ("BUNDLE_CONTENTS: " ^ upstream_version);
        update_client#set_latest_version upstream_version;
      );
      StateReached GettingVersionInfo;
      StateReached (Downloading upstream_version);
      StateReached (Installing (_MAGIC_PAT ^ expected_bundle_name upstream_version));
      ActionDone
        ( "bundle was installed into secondary slot",
          fun () ->
            let status = rauc#get_slot_status SystemB in
            let () =
              Alcotest.(check string)
                "Secondary slot has the newly downloaded bundle's version"
                upstream_version status.version
            in
            Lwt.return true );
      StateReached RebootRequired;
      StateReached GettingVersionInfo;
    ]
  in
  (expected_state_sequence, init_state)

let both_newer_than_upstream =
  let input_versions = {
        booted = semver_v3;
        inactive = semver_v2;
        latest = semver_v1;
  } in
  let expected_state =
      UpToDate input_versions
  in
  test_version_logic_case ~input_versions expected_state

let booted_newer_secondary_older =
  let input_versions = {
        latest = semver_v2;
        booted = semver_v3;
        inactive = semver_v1;
  } in
  let expected_state =
      UpToDate input_versions
  in
  test_version_logic_case ~input_versions expected_state

let booted_older_secondary_newer =
  let input_versions = {
        latest = semver_v2;
        booted = semver_v1;
        inactive = semver_v3;
  } in
  let expected_state =
      OutOfDateVersionSelected
  in
  test_version_logic_case ~input_versions expected_state

let booted_current_secondary_current =
  let input_versions = {
        latest = semver_v2;
        booted = semver_v2;
        inactive = semver_v2;
  } in
  let expected_state =
      UpToDate input_versions
  in
  test_version_logic_case ~input_versions expected_state

let booted_current_secondary_older =
  let input_versions = {
        latest = semver_v2;
        booted = semver_v2;
        inactive = semver_v1;
  } in
  let expected_state =
      UpToDate input_versions
  in
  test_version_logic_case ~input_versions expected_state

let booted_older_secondary_current =
  let input_versions = {
        latest = semver_v2;
        booted = semver_v1;
        inactive = semver_v2;
  } in
  let expected_state = OutOfDateVersionSelected
  in
  test_version_logic_case ~input_versions expected_state


let possible_versions = [semver_v1; semver_v2; semver_v3]
let possible_booted_slots = [Rauc.Slot.SystemA; Rauc.Slot.SystemB]
let possible_primary_slots =
    None :: List.map (Option.some) possible_booted_slots

let flatten_tuple (a, (b, c)) = (a, b, c)

let combine3 l1 l2 l3 =
    List.combine l1 (List.combine l2 l3) |>
        List.map flatten_tuple

let product l1 l2 =
    List.concat_map
        (fun e1 -> List.map (fun e2 -> (e1, e2)) l2)
        l1

let product3 l1 l2 l3 =
    product l1 (product l2 l3) |>
        List.map flatten_tuple

let vsn_triple_to_version_info (latest, booted, inactive) = {
    latest = latest;
    booted = booted;
    inactive = inactive;
}

let all_possible_combos =
    let vsn_triples = product3 possible_versions possible_versions possible_versions in
    let combos = product3 vsn_triples possible_booted_slots possible_primary_slots in
    List.map (fun (vsns, booted_slot, primary_slot) ->
        let vsn_info = vsn_triple_to_version_info vsns in
        {
            booted_slot = booted_slot;
            primary_slot = primary_slot;
            input_versions = vsn_info;
        })
        combos


let () =
  let () = setup_log () in
  Lwt_main.run
  @@ Alcotest_lwt.run "UpdateService tests"
       [
         ( "Booted = Primary",
           [
            (* BOOTED = PRIMARY in all these *)
             Alcotest_lwt.test_case
                "Both slots out of date -> Update"
                `Quick (fun _ () -> run_test_case both_out_of_date);
             Alcotest_lwt.test_case
                "Both slots newer than upstream -> UpToDate"
                `Quick (fun _ () -> run_test_case both_newer_than_upstream);
             Alcotest_lwt.test_case
                "Booted slot current, inactive older -> UpToDate"
                `Quick (fun _ () -> run_test_case booted_current_secondary_older);
             Alcotest_lwt.test_case
                "Booted slot older, inactive current -> UpToDate"
                `Quick (fun _ () -> run_test_case booted_older_secondary_current);
             Alcotest_lwt.test_case
                "Booted slot current, inactive current -> UpToDate"
                `Quick (fun _ () -> run_test_case booted_current_secondary_current);
             Alcotest_lwt.test_case
                "Booted slot newer, inactive older -> UpToDate"
                `Quick (fun _ () -> run_test_case booted_newer_secondary_older);
             Alcotest_lwt.test_case
                "Booted slot older, inactive newer -> OutOfDateVersionSelected"
                `Quick (fun _ () -> run_test_case booted_older_secondary_newer);
           ]);
           ( "Version cases matrix",
             List.map test_combo_matrix_case all_possible_combos
           )
       ]
