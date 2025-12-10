open Update
open Test_mocks
open Update_test_helpers

(* Main test scenario: full update process *)
let both_out_of_date ({ update_client; rauc } : Helpers.test_context) =
  let booted_version = "10.0.0" in
  let inactive_version = "9.0.0" in
  let upstream_version = "10.0.2" in
  let vsn_info =
    { booted = Semver.of_string booted_version |> Option.get
    ; inactive = Semver.of_string inactive_version |> Option.get
    ; latest = Semver.of_string upstream_version |> Option.get
    }
  in
  let expected_bundle_name vsn =
    Mock_update_client.test_bundle_name ^ Scenario._WILDCARD_PAT ^ vsn
    ^ Scenario._WILDCARD_PAT
  in
  let base_expected_state =
    { version_info = Some vsn_info
    ; system_status = NeedsUpdate
    ; process_state = GettingVersionInfo
    }
  in
  let expected_state_sequence =
    [ Scenario.UpdateMock
        (fun () ->
          rauc#set_version SystemA booted_version ;
          rauc#set_version SystemB inactive_version ;
          rauc#set_booted_slot SystemA ;
          update_client#add_bundle upstream_version
            ("BUNDLE_CONTENTS: " ^ upstream_version) ;
          update_client#set_latest_version upstream_version
        )
    ; Scenario.StateReached Update.initial_state
    ; Scenario.StateReached
        { base_expected_state with
          process_state = Downloading upstream_version
        }
    ; Scenario.StateReached
        { base_expected_state with
          process_state =
            Installing
              (Scenario._WILDCARD_PAT ^ expected_bundle_name upstream_version)
        }
    ; Scenario.ActionDone
        ( "bundle was installed into secondary slot"
        , fun _ ->
            let status = rauc#get_slot_status SystemB in
            let () =
              Alcotest.(check string)
                "Secondary slot has the newly downloaded bundle's version"
                upstream_version status.version
            in
            Lwt.return true
        )
    ; Scenario.ActionDone
        ( "bundle file was deleted after successful installation"
        , fun { process_state = Installing path; _ } ->
            Alcotest.(check bool)
              "File no longer exists at path" false (Sys.file_exists path) ;
            Lwt.return true
        )
    ; Scenario.StateReached
        { base_expected_state with
          version_info = None
        ; process_state = GettingVersionInfo
        }
    ; Scenario.StateReached
        { version_info = Some { vsn_info with inactive = vsn_info.latest }
        ; system_status = RebootRequired
        ; process_state =
            Sleeping Helpers.default_test_config.check_for_updates_interval
        }
    ]
  in
  (expected_state_sequence, Update.initial_state)

let delete_downloaded_bundle_on_err
    ({ update_client; rauc } : Helpers.test_context) =
  let inactive_version = "9.0.0" in
  let booted_version = inactive_version in
  let upstream_version = "10.0.0" in
  let vsn_info =
    { booted = Semver.of_string booted_version |> Option.get
    ; inactive = Semver.of_string inactive_version |> Option.get
    ; latest = Semver.of_string upstream_version |> Option.get
    }
  in
  let init_state =
    { system_status = NeedsUpdate
    ; version_info = Some vsn_info
    ; process_state = Downloading upstream_version
    }
  in
  let expected_bundle_name vsn =
    Mock_update_client.test_bundle_name ^ Scenario._WILDCARD_PAT ^ vsn
    ^ Scenario._WILDCARD_PAT
  in
  let expected_state_sequence =
    [ Scenario.UpdateMock
        (fun () ->
          rauc#set_version SystemB inactive_version ;
          rauc#set_booted_slot SystemA ;
          (* bundles that do not contain their own version will be treated
             as invalid by mock RAUC *)
          update_client#add_bundle upstream_version "CORRUPT_BUNDLE_CONTENTS"
        )
    ; Scenario.StateReached init_state
    ; Scenario.StateReached
        { init_state with
          process_state =
            Installing
              (Scenario._WILDCARD_PAT ^ expected_bundle_name upstream_version)
        }
    ; Scenario.ActionDone
        ( "bundle was deleted from path due to installation error"
        , fun { process_state = Installing path; _ } ->
            let status = rauc#get_slot_status SystemB in
            Alcotest.(check string)
              "Inactive slot remains in the same version" inactive_version
              status.version ;
            Alcotest.(check bool)
              "Downloaded corrupt bundle was deleted" false
              (Sys.file_exists path) ;
            Lwt.return true
        )
    ; Scenario.StateReached
        { init_state with
          process_state =
            Sleeping Helpers.default_test_config.install_error_backoff_duration
        ; system_status = UpdateError (ErrorInstalling Scenario._WILDCARD_PAT)
        }
    ; Scenario.StateReached
        { init_state with
          process_state = GettingVersionInfo
        ; system_status = UpdateError (ErrorInstalling Scenario._WILDCARD_PAT)
        }
    ]
  in
  (expected_state_sequence, init_state)

let sleep_on_get_version_err _ () =
  let always_fail_gen () = Lwt.return true in
  let { update_service; _ } : Helpers.test_context =
    Helpers.init_test_deps ~failure_gen_upd:always_fail_gen ()
  in
  let module UpdateServiceI = (val update_service) in
  let init_state = Update.initial_state in
  let expected_state =
    { version_info = None
    ; system_status =
        UpdateError (ErrorGettingVersionInfo Scenario._WILDCARD_PAT)
    ; process_state =
        Sleeping Helpers.default_test_config.http_error_backoff_duration
    }
  in
  let%lwt out_state = UpdateServiceI.run_step init_state in
  Lwt.return
  @@ Alcotest.check Scenario.testable_state "Output state matches"
       expected_state out_state

let sleep_on_download_err _ () =
  let always_fail_gen () = Lwt.return true in
  let { update_service; _ } : Helpers.test_context =
    Helpers.init_test_deps ~failure_gen_upd:always_fail_gen ()
  in
  let module UpdateServiceI = (val update_service) in
  let init_state : Update.state =
    { version_info =
        Some { latest = Helpers.v2; booted = Helpers.v1; inactive = Helpers.v1 }
    ; system_status = NeedsUpdate
    ; process_state = Downloading (Semver.to_string Helpers.v2)
    }
  in
  let expected_state =
    { version_info = None
    ; system_status = UpdateError (ErrorDownloading Scenario._WILDCARD_PAT)
    ; process_state =
        Sleeping Helpers.default_test_config.http_error_backoff_duration
    }
  in
  let%lwt out_state = UpdateServiceI.run_step init_state in
  Lwt.return
  @@ Alcotest.check Scenario.testable_state "Output state matches"
       expected_state out_state

let both_newer_than_upstream =
  let input_versions =
    { booted = Helpers.v3; inactive = Helpers.v2; latest = Helpers.v1 }
  in
  let expected_state = UpToDate in
  Scenario.scenario_from_system_spec ~input_versions expected_state

let booted_newer_secondary_older =
  let input_versions =
    { latest = Helpers.v2; booted = Helpers.v3; inactive = Helpers.v1 }
  in
  let expected_state = UpToDate in
  Scenario.scenario_from_system_spec ~input_versions expected_state

let booted_older_secondary_newer =
  let input_versions =
    { latest = Helpers.v2; booted = Helpers.v1; inactive = Helpers.v3 }
  in
  let expected_state = OutOfDateVersionSelected in
  Scenario.scenario_from_system_spec ~input_versions expected_state

let booted_current_secondary_current =
  let input_versions =
    { latest = Helpers.v2; booted = Helpers.v2; inactive = Helpers.v2 }
  in
  let expected_state = UpToDate in
  Scenario.scenario_from_system_spec ~input_versions expected_state

let booted_current_secondary_older =
  let input_versions =
    { latest = Helpers.v2; booted = Helpers.v2; inactive = Helpers.v1 }
  in
  let expected_state = UpToDate in
  Scenario.scenario_from_system_spec ~input_versions expected_state

let booted_older_secondary_current =
  let input_versions =
    { latest = Helpers.v2; booted = Helpers.v1; inactive = Helpers.v2 }
  in
  let expected_state = OutOfDateVersionSelected in
  Scenario.scenario_from_system_spec ~input_versions expected_state

let () =
  Lwt_main.run
  @@ Alcotest_lwt.run "UpdateService tests"
       [ ( "Main cases, booted = primary"
         , [ (* BOOTED = PRIMARY in all these *)
             Alcotest_lwt.test_case "Both slots out of date -> Update" `Quick
               (fun _ () -> Scenario.run both_out_of_date
             )
           ; Alcotest_lwt.test_case "Both slots newer than upstream -> UpToDate"
               `Quick (fun _ () -> Scenario.run both_newer_than_upstream
             )
           ; Alcotest_lwt.test_case
               "Booted slot current, inactive older -> UpToDate" `Quick
               (fun _ () -> Scenario.run booted_current_secondary_older
             )
           ; Alcotest_lwt.test_case
               "Booted slot older, inactive current -> UpToDate" `Quick
               (fun _ () -> Scenario.run booted_older_secondary_current
             )
           ; Alcotest_lwt.test_case
               "Booted slot current, inactive current -> UpToDate" `Quick
               (fun _ () -> Scenario.run booted_current_secondary_current
             )
           ; Alcotest_lwt.test_case
               "Booted slot newer, inactive older -> UpToDate" `Quick
               (fun _ () -> Scenario.run booted_newer_secondary_older
             )
           ; Alcotest_lwt.test_case
               "Booted slot older, inactive newer -> OutOfDateVersionSelected"
               `Quick (fun _ () -> Scenario.run booted_older_secondary_newer
             )
           ]
         )
       ; ( "Error handling"
         , [ Alcotest_lwt.test_case "Delete downloaded bundle on install error"
               `Quick (fun _ () -> Scenario.run delete_downloaded_bundle_on_err
             )
           ; Alcotest_lwt.test_case
               "Update enters sleep after get version error" `Quick
               sleep_on_get_version_err
           ; Alcotest_lwt.test_case
               "Update enters sleep after get download error" `Quick
               sleep_on_get_version_err
           ]
         )
       ; ( "All version/slot combinations"
         , List.map Outcome.test_slot_spec Helpers.all_possible_slot_spec_combos
         )
       ]
