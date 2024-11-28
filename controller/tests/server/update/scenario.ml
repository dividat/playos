(**
    Update scenario spec framework.
*)

type action_descr = string

type action_check = Update.state -> bool Lwt.t

type mock_update = unit -> unit

type scenario_spec =
  | StateReached of Update.state
  | ActionDone of action_descr * action_check
  | UpdateMock of mock_update

let specfmt spec =
  match spec with
  | StateReached s ->
      "StateReached: " ^ Helpers.statefmt s
  | ActionDone (descr, c) ->
      "ActionDone: " ^ descr
  | UpdateMock _ ->
      "UpdateMock: <fun>"

let _WILDCARD_PAT = "<..>"

(* string equality, but the magic pattern `<..>` is treated
   as a placeholder for any sub-string. The implementation converts the
   `expected` string to a regex where the magic pattern is replaced with ".*",
   while being careful to `Str.quote` the rest of the string to not accidentally
   treat them as regex expressions.
*)
let str_match_with_magic_pat expected actual =
  let open Str in
  let magic_pattern = regexp_string _WILDCARD_PAT in
  let exp_parts = full_split magic_pattern expected in
  let exp_regexp =
    regexp
    @@ String.concat ""
    @@ List.map
         (fun p -> match p with Text a -> quote a | Delim _ -> ".*")
         exp_parts
  in
  string_match exp_regexp actual 0

let testable_state =
  let state_to_str s =
    Update.sexp_of_state s
    (* using _hum instead of _mach, because _mach seems to remove
       whitespace between atoms in some cases *)
    |> Sexplib.Sexp.to_string_hum
    (* ignore whitespace differences *)
    |> Str.global_replace (Str.regexp_string "\n") ""
    |> Str.global_replace (Str.regexp "[ ]+") " "
  in
  let state_formatter out inp = Format.fprintf out "%s" (state_to_str inp) in
  let state_eq expected actual =
    expected == actual
    || str_match_with_magic_pat
         (* Using string repr is a horrible hack, but avoids having to
            pattern match on every variant in the state ADT *)
         (state_to_str expected)
         (state_to_str actual)
  in
  Alcotest.testable state_formatter state_eq

let interpret_spec (state : Update.state) (spec : scenario_spec) =
  match spec with
  | StateReached s ->
      Lwt.return @@ Alcotest.check testable_state (specfmt spec) s state
  | ActionDone (descr, f) ->
      let%lwt rez = f state in
      Lwt.return @@ Alcotest.(check bool) (specfmt spec) true rez
  | UpdateMock f ->
      Lwt.return @@ f ()

let is_state_spec s = match s with StateReached _ -> true | _ -> false

let is_mock_spec s = match s with UpdateMock _ -> true | _ -> false

let rec lwt_while cond expr =
  if cond () then
    let%lwt () = expr () in
    lwt_while cond expr
  else Lwt.return ()

let check_state expected_state_sequence prev_state cur_state =
  let spec = Queue.pop expected_state_sequence in
  (* after a callback first spec should always be the next state we expect *)
  if not (is_state_spec spec) then
    failwith
    @@ "Expected a state spec, but got "
    ^ specfmt spec
    ^ " - bad spec?" ;
  (* check if state spec matches the prev_state (i.e. initial state) *)
  let%lwt () = interpret_spec prev_state spec in
  (* progress forward until we either reach the end or we hit a state
     spec, which means we have to progress the state machine *)
  lwt_while
    (fun () ->
      (not (Queue.is_empty expected_state_sequence))
      && not (is_state_spec @@ Queue.peek expected_state_sequence)
    )
    (fun () ->
      let next_spec = Queue.pop expected_state_sequence in
      interpret_spec prev_state next_spec
    )

let rec consume_mock_specs state_seq cur_state =
  let next = Queue.peek_opt state_seq in
  match next with
  | Some spec when is_mock_spec spec ->
      let _ = Queue.pop state_seq in
      let%lwt () = interpret_spec cur_state spec in
      consume_mock_specs state_seq cur_state
  | _ ->
      Lwt.return ()

let rec run_test_scenario (test_context : Helpers.test_context)
    expected_state_sequence cur_state =
  (* special case for specifying `MockUpdate`'s BEFORE any
     `StateReached` spec's to enable initialization of mocks *)
  let _ = consume_mock_specs expected_state_sequence cur_state in
  let module UpdateServiceI = (val test_context.update_service) in
  if not (Queue.is_empty expected_state_sequence) then
    let%lwt next_state = UpdateServiceI.run_step cur_state in
    let%lwt () = check_state expected_state_sequence cur_state next_state in
    run_test_scenario test_context expected_state_sequence next_state
  else Lwt.return ()

(* NOTE: this is almost the same as the `Outcome.test_slot_spec,
         except that it expects only a system state outcome and uses the
         `run_test_scenario` machinery. *)
let scenario_from_system_spec ?(booted_slot = Rauc.Slot.SystemA)
    ?(primary_slot = Some Rauc.Slot.SystemA)
    ~(input_versions : Update.version_info)
    (expected_system_status : Update.system_status) =
  let init_state = Update.initial_state in
  let expected_state : Update.state =
    { version_info = Some input_versions
    ; system_status = expected_system_status
    ; process_state =
        Sleeping Helpers.default_test_config.check_for_updates_interval
    }
  in
  fun mocks ->
    let expected_state_sequence =
      [ UpdateMock
          (fun () ->
            Helpers.setup_mocks_from_system_slot_spec mocks
              { booted_slot; primary_slot; input_versions }
          )
      ; StateReached Update.initial_state
      ; StateReached expected_state
      ]
    in
    (expected_state_sequence, init_state)

let run scenario_gen =
  let test_context = Helpers.init_test_deps () in
  let scenario, init_state = scenario_gen test_context in
  run_test_scenario test_context
    (Queue.of_seq (List.to_seq scenario))
    init_state
