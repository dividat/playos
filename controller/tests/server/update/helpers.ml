(* ==== Misc helpers ==== *)

let other_slot slot = match slot with
    | Rauc.Slot.SystemA -> Rauc.Slot.SystemB
    | Rauc.Slot.SystemB -> Rauc.Slot.SystemA

let slot_to_string = function
    | Rauc.Slot.SystemA -> "SystemA"
    | Rauc.Slot.SystemB -> "SystemB"

let version_info_to_string ({latest; booted; inactive}: Update.version_info) =
    Format.sprintf "{latest=%s booted=%s inactive=%s}"
        (Semver.to_string latest)
        (Semver.to_string booted)
        (Semver.to_string inactive)

let statefmt (state : Update.state) : string =
  state |> Update.sexp_of_state |> Sexplib.Sexp.to_string_hum

(* === Mock init and setup === *)

let default_test_config : Update.config = {
  error_backoff_duration = 0.01;
  check_for_updates_interval = 0.05;
}

type test_context = {
    update_client : Mock_update_client.mock;
    rauc : Mock_rauc.mock;
    update_service : (module Update.UpdateService)
}

(* see [init_test_deps] for usage *)
let no_failure_gen = fun () -> Lwt.return false

(* Creates fresh instances of UpdateClient, Rauc_service and UpdateService.
   `failure_gen_*` can be used to specify random fault injection generators,
   see `update_prop_tests.ml` for usage *)
let init_test_deps
        ?(failure_gen_rauc=no_failure_gen) ?(failure_gen_upd=no_failure_gen)
        ?(test_config=default_test_config)
        () : test_context =
    let update_client = new Mock_update_client.mock failure_gen_upd in
    let rauc = new Mock_rauc.mock failure_gen_rauc in
    let module TestUpdateServiceDeps = struct
      module ClientI = (val update_client#to_module)
      module RaucI = (val rauc#to_module)
      let config = test_config
    end in
    let module TestUpdateService = Update.Make (TestUpdateServiceDeps) in
    {
        update_client = update_client;
        rauc = rauc;
        update_service = (module TestUpdateService)
    }

type system_slot_spec = {
    booted_slot: Rauc.Slot.t;
    primary_slot: Rauc.Slot.t Option.t;
    input_versions: Update.version_info;
}

let setup_mocks_from_system_slot_spec {rauc; update_client} case =
    let {booted_slot; primary_slot; input_versions} = case in

    let booted_version = Semver.to_string input_versions.booted in
    let secondary_version = Semver.to_string input_versions.inactive in
    let upstream_version = Semver.to_string input_versions.latest in

    let inactive_slot = other_slot booted_slot in

    rauc#set_version booted_slot booted_version;
    rauc#set_version inactive_slot secondary_version;
    rauc#set_booted_slot booted_slot;
    rauc#set_primary primary_slot;
    update_client#set_latest_version upstream_version;
    ()


(* ==== Test data and data generation ==== *)

let v1 = Semver.of_string "1.0.0" |> Option.get
let v2 = Semver.of_string "2.0.0" |> Option.get
let v3 = Semver.of_string "3.0.0" |> Option.get

let flatten_tuple (a, (b, c)) = (a, b, c)

let product l1 l2 =
    List.concat_map
        (fun e1 -> List.map (fun e2 -> (e1, e2)) l2)
        l1

let product3 l1 l2 l3 =
    product l1 (product l2 l3) |>
        List.map flatten_tuple

let possible_versions = [v1; v2; v3]
let possible_booted_slots = [Rauc.Slot.SystemA; Rauc.Slot.SystemB]
let possible_primary_slots =
    None :: List.map (Option.some) possible_booted_slots

let vsn_triple_to_version_info (latest, booted, inactive) : Update.version_info = {
    latest = latest;
    booted = booted;
    inactive = inactive;
}

let all_possible_slot_spec_combos =
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


(* === Test case predicates for test_slot_spec_combo_case ===  *)

type expected_outcomes =
    | DoNothingOrProduceWarning
    | InstallVsn of (Semver.t [@sexp.opaque])
    [@@deriving sexp]

(* Similar to `evaluate_version_info` in `update.ml`, but reduced to only two
   outcomes: installing the update or not installing the update.
*)
let slot_spec_to_outcome {booted_slot; primary_slot; input_versions} =
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


let slot_spec_to_string {booted_slot; primary_slot; input_versions} =
    Format.sprintf
            "booted=%s\tprimary=%s\tvsns%s"
            (slot_to_string booted_slot)
            (Option.map slot_to_string primary_slot |> Option.value ~default:"-")
            (version_info_to_string input_versions)

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
            (slot_spec_to_string case)
            expected_outcome_str
    in
    Alcotest_lwt.test_case test_case_descr `Quick (fun _ () ->
        let mocks = init_test_deps () in

        let () = setup_mocks_from_system_slot_spec mocks case in

        let module UpdateServiceI = (val mocks.update_service) in
        let%lwt out_state = UpdateServiceI.run_step GettingVersionInfo in
        if state_matches_expected_outcome out_state expected_outcome then
            Lwt.return ()
        else
            Alcotest.fail (Format.sprintf
                "Reached state [%s] does not match expected outcome [%s]"
                (statefmt out_state)
                expected_outcome_str
            )
    )
