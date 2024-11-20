(**
    Test outcome, be it install version, or do nothing / produce warning.
*)

type expected_outcomes =
    | DoNothingOrProduceWarning
    | InstallVsn of (Semver.t [@sexp.opaque])
    [@@deriving sexp]

(* Similar to `evaluate_version_info` in `update.ml`, but reduced to only two
   outcomes: installing the update or not installing the update.
*)
let slot_spec_to_outcome ({booted_slot; primary_slot; input_versions} : Helpers.system_slot_spec) =
    let booted_is_out_of_date =
        (Semver.compare input_versions.booted input_versions.latest) = -1
    in
    let inactive_is_out_of_date =
        (Semver.compare input_versions.inactive input_versions.latest) = -1
    in
    if booted_is_out_of_date && inactive_is_out_of_date then
        InstallVsn input_versions.latest
    else
        DoNothingOrProduceWarning

(* Checks if the state returned by UpdateService matches
   the expected outcome as determined by [slot_spec_to_outcome] *)
let state_matches_expected_outcome state outcome =
    match (outcome, state) with
        | (InstallVsn v1,             Update.Downloading v2) ->
                (Semver.to_string v1) = v2
        | (InstallVsn _,              _) ->                         false
        | (DoNothingOrProduceWarning, Update.ErrorGettingVersionInfo _) -> true
        | (DoNothingOrProduceWarning, Update.UpToDate _) ->                true
        | (DoNothingOrProduceWarning, Update.OutOfDateVersionSelected) ->  true
        | (DoNothingOrProduceWarning, Update.RebootRequired) ->            true
        | (DoNothingOrProduceWarning, Update.ReinstallRequired) ->         true
        (* should not _directly_ return to GettingVersionInfo state *)
        | (DoNothingOrProduceWarning, Update.GettingVersionInfo) ->        false
        (* all the other states are part of the installation process
           and are treated as errors *)
        | (DoNothingOrProduceWarning, _) ->                         false

(** Tests if the input UpdateService run with the given [system_slot_spec]
    [case] scenario produces the expected outcome state (defined by
    [slot_spec_to_outcome] and [state_matches_expected_outcome]).

    This is used to test that all possible booted/primary and version
    combinations lead to the correct install/no-install action.
*)
let test_slot_spec_combo_case case =
    let expected_outcome = slot_spec_to_outcome case in
    let expected_outcome_str =
            (sexp_of_expected_outcomes expected_outcome |> Sexplib.Sexp.to_string)
    in
    let test_case_descr =
        Format.sprintf
            "%s\t->\t%s"
            (Helpers.slot_spec_to_string case)
            expected_outcome_str
    in
    Alcotest_lwt.test_case test_case_descr `Quick (fun _ () ->
        let mocks = Helpers.init_test_deps () in

        let () = Helpers.setup_mocks_from_system_slot_spec mocks case in

        let module UpdateServiceI = (val mocks.update_service) in
        let%lwt out_state = UpdateServiceI.run_step GettingVersionInfo in
        if state_matches_expected_outcome out_state expected_outcome then
            Lwt.return ()
        else
            Alcotest.fail (Format.sprintf
                "Reached state [%s] does not match expected outcome [%s]"
                (Helpers.statefmt out_state)
                expected_outcome_str
            )
    )
