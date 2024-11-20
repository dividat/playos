open Update

(* Main test scenario: full update process *)
let both_out_of_date ({update_client; rauc}: Helpers.test_context) =
  let init_state = GettingVersionInfo in
  let booted_version = "10.0.0" in
  let inactive_version = "9.0.0" in
  let upstream_version = "10.0.2" in

  let expected_bundle_name vsn =
      Mock_update_client.test_bundle_name ^ Scenario._WILDCARD_PAT ^ vsn ^ Scenario._WILDCARD_PAT
  in

  let expected_state_sequence =
    [
      Scenario.UpdateMock (fun () ->
        rauc#set_version SystemA booted_version;
        rauc#set_version SystemB inactive_version;
        rauc#set_booted_slot SystemA;

        update_client#add_bundle upstream_version
            ("BUNDLE_CONTENTS: " ^ upstream_version);
        update_client#set_latest_version upstream_version;
      );
      Scenario.StateReached GettingVersionInfo;
      Scenario.StateReached (Downloading upstream_version);
      Scenario.StateReached (Installing (Scenario._WILDCARD_PAT ^ expected_bundle_name upstream_version));
      Scenario.ActionDone
        ( "bundle was installed into secondary slot",
          fun _ ->
            let status = rauc#get_slot_status SystemB in
            let () =
              Alcotest.(check string)
                "Secondary slot has the newly downloaded bundle's version"
                upstream_version status.version
            in
            Lwt.return true );
      Scenario.StateReached RebootRequired;
      Scenario.StateReached GettingVersionInfo;
    ]
  in
  (expected_state_sequence, init_state)

let delete_downloaded_bundle_on_err ({update_client; rauc}: Helpers.test_context) =
  let inactive_version = "9.0.0" in
  let upstream_version = "10.0.0" in

  let init_state = Downloading upstream_version in
  let expected_bundle_name vsn =
      Mock_update_client.test_bundle_name ^ Scenario._WILDCARD_PAT ^ vsn ^ Scenario._WILDCARD_PAT
  in

  let expected_state_sequence =
    [
      Scenario.UpdateMock (fun () ->
        rauc#set_version SystemB inactive_version;
        rauc#set_booted_slot SystemA;
        (* bundles that do not contain their own version will be treated
           as invalid by mock RAUC *)
        update_client#add_bundle upstream_version "CORRUPT_BUNDLE_CONTENTS"
      );
      Scenario.StateReached (Downloading upstream_version);
      Scenario.StateReached (Installing (Scenario._WILDCARD_PAT ^ expected_bundle_name upstream_version));
      Scenario.ActionDone
        ( "bundle was deleted from path due to installation error",
          fun (Installing path) ->
            let status = rauc#get_slot_status SystemB in
            Alcotest.(check string)
                "Inactive slot remains in the same version"
                 inactive_version status.version;
            Alcotest.(check bool)
                "Downloaded corrupt bundle was deleted"
                false (Sys.file_exists path);
            Lwt.return true );
      Scenario.StateReached (ErrorInstalling Scenario._WILDCARD_PAT);
      Scenario.StateReached GettingVersionInfo;
    ]
  in
  (expected_state_sequence, init_state)

let sleep_after_error_or_check_test () =
  (* long-ish timeouts, but these will run in parallel, so no biggie *)
  let test_config = {
    error_backoff_duration = 1.0;
    check_for_updates_interval = 2.0;
  } in

  let ({update_service; _}: Helpers.test_context) = Helpers.init_test_deps ~test_config () in
  let module UpdateServiceI = (val update_service) in

  let error_states = [
      ErrorGettingVersionInfo "err";
      ErrorInstalling "err";
      ErrorDownloading "err";
  ] in
  let post_check_states = [
      UpToDate (Helpers.vsn_triple_to_version_info (Helpers.v1, Helpers.v1, Helpers.v1));
      RebootRequired;
      OutOfDateVersionSelected;
      ReinstallRequired;
  ] in

  let test_state expected_timeout inp_state =
      let start_time = Unix.gettimeofday () in
      (* NOTE: running the same step TWICE to ensure
         that we execute the code in the same thread multiple times *)
      let%lwt _ = UpdateServiceI.run_step inp_state in
      let%lwt _ = UpdateServiceI.run_step inp_state in
      let end_time = Unix.gettimeofday () in
      let elasped_seconds = end_time -. start_time in
      if elasped_seconds > (expected_timeout *. 2.0) then
          Lwt.return ()
      else
          Lwt.return @@ Alcotest.fail @@
            Format.sprintf "Slept shorter than expected (expected %f; slept %f) after state %s"
                (expected_timeout *. 2.0) elasped_seconds (Helpers.statefmt inp_state)
   in
   Lwt.join @@
    (List.map (test_state test_config.error_backoff_duration) error_states)
    @
    (List.map (test_state test_config.check_for_updates_interval) post_check_states)


let both_newer_than_upstream =
  let input_versions = {
        booted = Helpers.v3;
        inactive = Helpers.v2;
        latest = Helpers.v1;
  } in
  let expected_state =
      UpToDate input_versions
  in
  Scenario.test_version_logic_case ~input_versions expected_state

let booted_newer_secondary_older =
  let input_versions = {
        latest = Helpers.v2;
        booted = Helpers.v3;
        inactive = Helpers.v1;
  } in
  let expected_state =
      UpToDate input_versions
  in
  Scenario.test_version_logic_case ~input_versions expected_state

let booted_older_secondary_newer =
  let input_versions = {
        latest = Helpers.v2;
        booted = Helpers.v1;
        inactive = Helpers.v3;
  } in
  let expected_state =
      OutOfDateVersionSelected
  in
  Scenario.test_version_logic_case ~input_versions expected_state

let booted_current_secondary_current =
  let input_versions = {
        latest = Helpers.v2;
        booted = Helpers.v2;
        inactive = Helpers.v2;
  } in
  let expected_state =
      UpToDate input_versions
  in
  Scenario.test_version_logic_case ~input_versions expected_state

let booted_current_secondary_older =
  let input_versions = {
        latest = Helpers.v2;
        booted = Helpers.v2;
        inactive = Helpers.v1;
  } in
  let expected_state =
      UpToDate input_versions
  in
  Scenario.test_version_logic_case ~input_versions expected_state

let booted_older_secondary_current =
  let input_versions = {
        latest = Helpers.v2;
        booted = Helpers.v1;
        inactive = Helpers.v2;
  } in
  let expected_state = OutOfDateVersionSelected
  in
  Scenario.test_version_logic_case ~input_versions expected_state

let () =
  Lwt_main.run
  @@ Alcotest_lwt.run "UpdateService tests"
       [
         ( "Main cases, booted = primary",
           [
             (* BOOTED = PRIMARY in all these *)
             Alcotest_lwt.test_case "Both slots out of date -> Update" `Quick
               (fun _ () -> Scenario.run both_out_of_date);
             Alcotest_lwt.test_case "Both slots newer than upstream -> UpToDate"
               `Quick (fun _ () -> Scenario.run both_newer_than_upstream);
             Alcotest_lwt.test_case
               "Booted slot current, inactive older -> UpToDate" `Quick
               (fun _ () -> Scenario.run booted_current_secondary_older);
             Alcotest_lwt.test_case
               "Booted slot older, inactive current -> UpToDate" `Quick
               (fun _ () -> Scenario.run booted_older_secondary_current);
             Alcotest_lwt.test_case
               "Booted slot current, inactive current -> UpToDate" `Quick
               (fun _ () -> Scenario.run booted_current_secondary_current);
             Alcotest_lwt.test_case
               "Booted slot newer, inactive older -> UpToDate" `Quick
               (fun _ () -> Scenario.run booted_newer_secondary_older);
             Alcotest_lwt.test_case
               "Booted slot older, inactive newer -> OutOfDateVersionSelected"
               `Quick (fun _ () -> Scenario.run booted_older_secondary_newer);
           ] );
         ( "Error handling",
           [
             Alcotest_lwt.test_case "Delete downloaded bundle on install error"
             `Quick (fun _ () -> Scenario.run delete_downloaded_bundle_on_err);

             Alcotest_lwt.test_case "Sleep for a duration after error or check"
             `Quick (fun _ () -> sleep_after_error_or_check_test ());
           ] );
         ( "All version/slot combinations",
           List.map Helpers.test_slot_spec_combo_case Helpers.all_possible_slot_spec_combos );
       ]