open Update
open Lwt

type test_context = {
    update_client : Mock_update_client.mock;
    rauc : Mock_rauc.mock;
    update_service : (module UpdateService)
}

let test_config : config = {
  error_backoff_duration = 0.01;
  check_for_updates_interval = 0.05;
}


type action_descr = string
type action_check = unit -> bool Lwt.t
type mock_update = unit -> unit

type scenario_spec =
  | StateReached of Update.state
  | ActionDone of action_descr * action_check
  | UpdateMock of mock_update

let statefmt (state : Update.state) : string =
  state |> Update.sexp_of_state |> Sexplib.Sexp.to_string_hum

let specfmt spec = match spec with
    | StateReached s -> "StateReached: " ^ (statefmt s);
    | ActionDone (descr, c) -> "ActionDone: " ^ descr;
    | UpdateMock _ -> "UpdateMock: <fun>"

let _MAGIC_PAT = "<..>"

(* string equality, but the magic patern `<..>` is treated
  as a placeholder for any sub-string. The implementation converts the
  `expected` string to a regex where the magic pattern is replaced with ".*",
  while being careful to `Str.quote` the rest of the string to not accidentally
  treat them as regex expressions.
*)
let str_match_with_magic_pat expected actual =
    let open Str in
    let magic_pattern = regexp_string _MAGIC_PAT in
    let exp_parts = full_split magic_pattern expected in
    let exp_regexp = regexp @@ String.concat "" @@ List.map (fun (p) ->
        match p with
            | Text a -> quote a
            | Delim a -> ".*"
    ) exp_parts in
    string_match exp_regexp actual 0


let state_formatter out inp = Format.fprintf out "%s" (statefmt inp)

let t_state =
    let state_eq expected actual =
        (expected == actual) || (
            str_match_with_magic_pat
                (* Using string repr is a horrible hack, but avoids having to
                   pattern match on every variant in the state ADT *)
                (Update.sexp_of_state expected |> Sexplib.Sexp.to_string)
                (Update.sexp_of_state actual |> Sexplib.Sexp.to_string)
        )
    in
    Alcotest.testable state_formatter state_eq


let interp_spec (state : Update.state) (spec : scenario_spec) =
  match spec with
  | StateReached s ->
      Lwt.return @@ Alcotest.check t_state (specfmt spec) s state
  | ActionDone (descr, f) ->
      let%lwt rez = f () in
      Lwt.return @@ Alcotest.(check bool) (specfmt spec) true rez
  | UpdateMock f -> Lwt.return @@ f ()

let is_state_spec s = match s with StateReached _ -> true | _ -> false
let is_mock_spec s = match s with UpdateMock _ -> true | _ -> false

let rec lwt_while cond expr =
    if (cond ()) then
        let%lwt () = expr () in
        lwt_while cond expr
    else
        Lwt.return ()

let check_state expected_state_sequence prev_state cur_state =
  let spec = Queue.pop expected_state_sequence in
  (* after a callback first spec should always be the next state we expect *)
  if not (is_state_spec spec) then
    failwith @@ "Expected a state spec, but got " ^ specfmt spec ^ " - bad spec?";

  (* check if state spec matches the prev_state (i.e. initial state) *)
  let%lwt () = interp_spec prev_state spec in

  (* progress forward until we either reach the end or we hit a state
     spec, which means we have to progress the state machine *)
  lwt_while
    (fun () ->
    (not (Queue.is_empty expected_state_sequence))
    && not (is_state_spec @@ Queue.peek expected_state_sequence))

    (fun () ->
    let next_spec = Queue.pop expected_state_sequence in
    interp_spec prev_state next_spec
    )

let rec consume_mock_specs state_seq cur_state =
  let next = Queue.peek_opt state_seq in
  match next with
    | Some spec when is_mock_spec spec ->
            let _ = Queue.pop state_seq in
            let%lwt () = interp_spec cur_state spec in
            consume_mock_specs state_seq cur_state
    | _ -> Lwt.return ()


let rec run_test_scenario test_context expected_state_sequence cur_state =
  (* special case for specifying `MockUpdate`'s BEFORE any
    `StateReached` spec's to enable initialization of mocks *)
  let _ = consume_mock_specs expected_state_sequence cur_state in
  let module UpdateServiceI = (val test_context.update_service) in

  if not (Queue.is_empty expected_state_sequence) then (
    let%lwt next_state = UpdateServiceI.run_step cur_state in
    let%lwt () = check_state expected_state_sequence cur_state next_state in
    run_test_scenario test_context expected_state_sequence next_state)
  else Lwt.return ()


(* creates fresh instances of UpdateClient, Rauc_service and UpdateService *)
let setup_test_deps () : test_context =
    let update_client = new Mock_update_client.mock in
    let rauc = new Mock_rauc.mock in
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

let run_test_case scenario_gen =
    let test_context = setup_test_deps ()  in
    let (scenario, init_state) = scenario_gen test_context in
    run_test_scenario test_context (Queue.of_seq (List.to_seq scenario)) init_state
