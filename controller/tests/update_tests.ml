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


let () =
  Lwt_main.run @@ Alcotest_lwt.run "UpdateService basic tests"
       [
         ( "Main cases, booted = primary",
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
           ( "All version/slot combinations",
             List.map test_slot_spec_combo_case all_possible_slot_spec_combos
           );
       ]
