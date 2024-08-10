open Update
open Lwt
open Mocks

module TestCurl = struct
  let request_default :
      (string * string) list option * string option * string list option * Uri.t ->
      Curl.result Lwt.t =
   fun _ -> failwith "Not defined"

  module Mock = MakeMockFun (val to_fun_mod request_default)

  let request ?headers ?data ?options url =
    Mock.run (headers, data, options, url)
end

let test_config : config = {
  error_backoff_duration = 0.01;
  check_for_updates_interval = 0.05;
  update_url = "https://localhost:9999/";
}

module TestUpdateServiceDeps = struct
  module CurlI = TestCurl
  module RaucI = Fake_rauc
  let config = test_config
end

module TestUpdateService = UpdateService (TestUpdateServiceDeps)

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



(* string equality, but the magic patern `___` is treated
  as a placeholder for any sub-string. The implementation converts the
  `expected` string to a regex where the magic pattern is replaced with ".*",
  while being careful to `Str.quote` the rest of the string to not accidentally
  treat them as regex expressions.
*)
let str_match_with_magic_pat expected actual =
    let open Str in
    let magic_pattern = regexp_string "___" in
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
        if (expected == actual) then true
        else
            (* Horrible hack, but avoids having to pattern match on every
               variant in the state ADT *)
            str_match_with_magic_pat
                (Update.sexp_of_state expected |> Sexplib.Sexp.to_string)
                (Update.sexp_of_state actual |> Sexplib.Sexp.to_string)
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


let rec run_test_scenario expected_state_sequence cur_state =
  (* special case for specifying `MockUpdate`'s BEFORE any
    `StateReached` spec's to enable initialization of mocks *)
  let _ = consume_mock_specs expected_state_sequence cur_state in

  (* is there an equivalent of Haskell's whileM ? *)
  if not (Queue.is_empty expected_state_sequence) then (
    let%lwt next_state = TestUpdateService.Private.run_step cur_state in
    let%lwt () = check_state expected_state_sequence cur_state next_state in
    run_test_scenario expected_state_sequence next_state)
  else Lwt.return ()

let reset_mocks () = begin
    Fake_rauc.reset_state ();
    TestCurl.Mock.reset ()
end

let run_test_case scenario_gen =
    let () = reset_mocks ()  in
    let (scenario, init_state) = scenario_gen () in
    run_test_scenario (Queue.of_seq (List.to_seq scenario)) init_state

let happy_flow_test () =
  let init_state = GettingVersionInfo in
  let current_version = "10.0.1" in
  let next_version = "10.0.2" in

  let expected_bundle_name =
    "@PLAYOS_BUNDLE_NAME@-" ^ next_version ^ ".raucb"
  in
  let expected_url =
    test_config.update_url ^ next_version ^ "/" ^ expected_bundle_name
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
            Alcotest.(check int)
              "Curl was called once" 1
              (Queue.length TestCurl.Mock.calls);
            let _ = Queue.pop TestCurl.Mock.calls in
            Lwt.return true );
      StateReached (Downloading { url = expected_url; version = next_version });
      ActionDone
        ( "curl was called",
          fun () ->
            match Queue.take_opt TestCurl.Mock.calls with
            | Some ((_, _, _, url), _) ->
                Alcotest.(check string)
                  "Curl was called with the right parameters" expected_url
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
