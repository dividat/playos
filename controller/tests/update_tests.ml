open Update
open Lwt
open Update_test_helpers

let happy_flow_test () =
  let init_state = GettingVersionInfo in
  let current_version = "10.0.1" in
  let next_version = "10.0.2" in

  let expected_bundle_name =
    "@PLAYOS_BUNDLE_NAME@-" ^ next_version ^ ".raucb"
  in
  let expected_url =
    Config.System.update_url ^ next_version ^ "/" ^ expected_bundle_name
  in

  let expected_state_sequence =
    [
      UpdateMock (fun () ->
        Fake_rauc.set_status SystemA {
            Fake_rauc.some_status with version = current_version
        };
        TestCurl.Mock.update_f (fun _ ->
            Curl.RequestSuccess (200, next_version) |> Lwt.return)
      );
      StateReached GettingVersionInfo;
      ActionDone
        ( "curl was called",
          fun () ->
            match Queue.take_opt TestCurl.Mock.calls with
            | Some ((_, _, _, url), _) ->
                Alcotest.(check string)
                  "Curl was called with the right parameters"
                  (Config.System.update_url ^ "latest")
                  (Uri.to_string url);
                Lwt.return true
            | _ -> Alcotest.fail "Curl was not called" );
      StateReached (Downloading { url = expected_url; version = next_version });
      ActionDone
        ( "curl was called",
          fun () ->
            match Queue.take_opt TestCurl.Mock.calls with
            | Some ((_, _, _, url), _) ->
                Alcotest.(check string)
                  "Curl was called with the right parameters"
                  expected_url
                  (Uri.to_string url);
                Lwt.return true
            | _ -> Alcotest.fail "Curl was not called" );
      StateReached (Installing ("/tmp/" ^ expected_bundle_name));
      ActionDone
        ( "bundle was installed and marked as primary",
          fun () ->
            let%lwt primary_opt = Fake_rauc.get_primary () in
            let primary =
              match primary_opt with
              | Some x -> x
              | _ -> Alcotest.fail "Primary was not set!"
            in
            let status = Fake_rauc.get_slot_status primary in
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

let not_so_happy_test () =
  let init_state = GettingVersionInfo in

  (* both slots have a newer version than fetch from update *)
  let installed_version = "10.0.0" in
  let next_version = "9.0.0" in

  let expected_state_sequence =
    [
      UpdateMock (fun () ->
        Fake_rauc.set_status SystemA {
            Fake_rauc.some_status with version = installed_version
        };
        Fake_rauc.set_status SystemB {
            Fake_rauc.some_status with version = installed_version
        };
        TestCurl.Mock.update_f (fun _ ->
            Curl.RequestSuccess (200, next_version) |> Lwt.return)
      );
      StateReached GettingVersionInfo;
      (* TODO: is this really a non-sensical scenario? *)
      StateReached
        (ErrorGettingVersionInfo "nonsensical version information: ___");
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
