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

let both_newer_than_upstream {update_client; rauc} =
  let init_state = GettingVersionInfo in

  (* both slots have a newer version than fetched from update *)
  let installed_version = "10.0.0" in
  let upstream_version = "9.0.0" in

  let expected_state_sequence =
    [
      UpdateMock (fun () ->
        rauc#set_version SystemA installed_version;
        rauc#set_version SystemB installed_version;
        rauc#set_primary SystemA;
        update_client#set_latest_version upstream_version
      );
      StateReached GettingVersionInfo;
      (* TODO: is this really a non-sensical scenario? *)
      StateReached
        (ErrorGettingVersionInfo "nonsensical version information: <..>");
      StateReached GettingVersionInfo;
    ]
  in
  (expected_state_sequence, init_state)

let booted_newer_secondary_older {update_client; rauc} =
  let init_state = GettingVersionInfo in

  let booted_version = "10.0.0" in
  let secondary_version = "8.0.0" in
  let upstream_version = "9.0.0" in

  let expected_state_sequence =
    [
      UpdateMock (fun () ->
        rauc#set_version SystemA booted_version;
        rauc#set_version SystemB secondary_version;
        rauc#set_booted_slot SystemA;
        rauc#set_primary SystemA;
        update_client#set_latest_version upstream_version
      );
      StateReached GettingVersionInfo;
      StateReached (Downloading upstream_version);
    ]
  in
  (expected_state_sequence, init_state)


let booted_older_secondary_newer {update_client; rauc} =
  let init_state = GettingVersionInfo in

  let booted_version = "8.0.0" in
  let secondary_version = "10.0.0" in
  let upstream_version = "9.0.0" in

  let expected_state_sequence =
    [
      UpdateMock (fun () ->
        rauc#set_version SystemA booted_version;
        rauc#set_version SystemB secondary_version;
        rauc#set_booted_slot SystemA;
        rauc#set_primary SystemA;
        update_client#set_latest_version upstream_version
      );
      StateReached GettingVersionInfo;
      StateReached
        (ErrorGettingVersionInfo "nonsensical version information: <..>");
    ]
  in
  (expected_state_sequence, init_state)

let setup_log () =
  Fmt_tty.setup_std_outputs ();
  Logs.set_level @@ Some Logs.Debug;
  Logs.set_reporter (Logs_fmt.reporter ());
  ()

let () =
  let () = setup_log () in
  Lwt_main.run
  @@ Alcotest_lwt.run "Basic tests"
       [
         ( "all",
           [
             Alcotest_lwt.test_case
                "Both slots out of date -> Update"
                `Quick (fun _ () -> run_test_case both_out_of_date);
             Alcotest_lwt.test_case
                "Both slots newer than upstream -> non-sensical err"
                `Quick (fun _ () -> run_test_case both_newer_than_upstream);
             Alcotest_lwt.test_case
                "Booted slot newer, inactive older -> Update"
                `Quick (fun _ () -> run_test_case booted_newer_secondary_older);
             Alcotest_lwt.test_case
                "Booted slot older, inactive newer -> non-sensical"
                `Quick (fun _ () -> run_test_case booted_older_secondary_newer);
           ]);
       ]
