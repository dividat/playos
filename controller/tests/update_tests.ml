open Update
open Lwt
open Update_test_helpers

let happy_flow_test {update_client; rauc} =
  let init_state = GettingVersionInfo in
  let installed_version = "10.0.1" in
  let next_version = "10.0.2" in

  let expected_bundle_name vsn =
      Mock_update_client.test_bundle_name ^ _MAGIC_PAT ^ vsn ^ _MAGIC_PAT
  in

  let initial_status : Rauc.Slot.status = {
      device = "Device";
      state = "Good";
      class' = "class";
      version = installed_version;
      installed_timestamp = "2023-01-01T00:00:00Z";
  } in

  let expected_state_sequence =
    [
      UpdateMock (fun () ->
        rauc#set_status SystemA initial_status;
        update_client#add_bundle next_version ("BUNDLE_CONTENTS: " ^ next_version);
        update_client#set_latest_version next_version;
      );
      StateReached GettingVersionInfo;
      StateReached (Downloading next_version);
      StateReached (Installing (_MAGIC_PAT ^ expected_bundle_name next_version));
      ActionDone
        ( "bundle was installed and marked as primary",
          fun () ->
            let%lwt primary_opt = rauc#get_primary () in
            let primary =
              match primary_opt with
              | Some x -> x
              | _ -> Alcotest.fail "Primary was not set!"
            in
            let status = rauc#get_slot_status primary in
            let () =
              Alcotest.(check string)
                "Primary version is set to the newly downloaded bundle"
                next_version status.version
            in
            Lwt.return true );
      StateReached RebootRequired;
      StateReached GettingVersionInfo;
    ]
  in
  (expected_state_sequence, init_state)

let not_so_happy_test {update_client; rauc} =
  let init_state = GettingVersionInfo in

  (* both slots have a newer version than fetched from update *)
  let installed_version = "10.0.0" in
  let next_version = "9.0.0" in

  let initial_status : Rauc.Slot.status = {
      device = "Device";
      state = "Good";
      class' = "class";
      version = installed_version;
      installed_timestamp = "2023-01-01T00:00:00Z";
  } in

  let expected_state_sequence =
    [
      UpdateMock (fun () ->
        rauc#set_status SystemA initial_status;
        rauc#set_status SystemB initial_status;
        update_client#set_latest_version next_version
      );
      StateReached GettingVersionInfo;
      (* TODO: is this really a non-sensical scenario? *)
      StateReached
        (ErrorGettingVersionInfo "nonsensical version information: <..>");
      StateReached GettingVersionInfo;
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
             Alcotest_lwt.test_case "Happy flow" `Quick (fun _ () ->
                 run_test_case happy_flow_test);
             Alcotest_lwt.test_case "Not so happy flow" `Quick (fun _ () ->
                 run_test_case not_so_happy_test);
           ]);
       ]
