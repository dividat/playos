open Update
open Lwt
open Mocks

let current_version = "10.0.1"
let next_version = "10.0.2"

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
type action_check = unit -> bool
type mock_update = unit -> unit

type scenario_spec =
  | StateReached of Update.state
  | ActionDone of action_descr * action_check
  | UpdateMock of mock_update

let statefmt (state : Update.state) : string =
  state |> Update.sexp_of_state |> Sexplib.Sexp.to_string_hum

let state_formatter out inp = Format.fprintf out "%s" (statefmt inp)
let t_state = Alcotest.testable state_formatter ( = )

let interp_spec (state : Update.state) (spec : scenario_spec) =
  match spec with
  | StateReached s -> Alcotest.check t_state "State reached" s state
  | ActionDone (descr, f) ->
      Alcotest.(check bool) ("Action done: " ^ descr) true (f ())
  | UpdateMock f -> f ()

let is_state_spec s = match s with StateReached _ -> true | _ -> false

let check_state expected_state_sequence prev_state cur_state =
  let spec = Queue.pop expected_state_sequence in
  (* after a callback first spec should always be the next state we expect
       *)
  if not (is_state_spec spec) then
    failwith "Expected a state spec, but got something else - bad spec?";

  interp_spec prev_state spec;
  (* progress forward until we either reach the end or we hit a state
     assertion, which means we have to progress the state machine *)
  while
    (not (Queue.is_empty expected_state_sequence))
    && not (is_state_spec @@ Queue.peek expected_state_sequence)
  do
    let next_spec = Queue.pop expected_state_sequence in
    interp_spec prev_state next_spec
  done

let rec run_test_scenario expected_state_sequence cur_state =
  (* is there an equivalent of Haskell's whileM ? *)
  if not (Queue.is_empty expected_state_sequence) then (
    let%lwt next_state = TestUpdateService.Private.run_step cur_state in
    check_state expected_state_sequence cur_state next_state;
    run_test_scenario expected_state_sequence next_state)
  else Lwt.return ()

let reset_mocks () =
    TestCurl.Mock.reset ()

let happy_flow_test () =
  (* TODO: move this to some test setup/teardown thing *)
  let () = reset_mocks () in
  let init_state = GettingVersionInfo in
  let expected_bundle_name =
    "@PLAYOS_BUNDLE_NAME@-" ^ next_version ^ ".raucb"
  in
  let expected_url =
    test_config.update_url ^ next_version ^ "/" ^ expected_bundle_name
  in

  let expected_state_sequence =
    let () =
      TestCurl.Mock.update_f (fun _ ->
          Curl.RequestSuccess (200, next_version) |> Lwt.return)
    in
    Queue.of_seq
      (List.to_seq
         [
           StateReached GettingVersionInfo;
           ActionDone
             ( "curl was called",
               fun () ->
                 Alcotest.(check int)
                   "Curl was called once" 1
                   (Queue.length TestCurl.Mock.calls);
                 let _ = Queue.pop TestCurl.Mock.calls in
                 true );
           StateReached
             (Downloading { url = expected_url; version = next_version });
           ActionDone
             ( "curl was called",
               fun () ->
                 match Queue.take_opt TestCurl.Mock.calls with
                 | Some ((_, _, _, url), _) ->
                     Alcotest.(check string)
                       "Curl was called with the right parameters" expected_url
                       (Uri.to_string url);
                     true
                 | _ -> Alcotest.fail "Curl was not called" );
           StateReached (Installing ("/tmp/" ^ expected_bundle_name));
           ActionDone ("bundle was installed and marked as primary",
            fun () ->
                Lwt_main.run @@ begin
                    let%lwt primary_opt = Fake_rauc.get_primary () in
                    let primary = (match primary_opt with
                        | Some x -> x
                        | _ -> Alcotest.fail "Primary was not set!")
                    in
                    let status = Fake_rauc.get_slot_status primary in
                    let () = Alcotest.(check string)
                        "Primary version is set to the newly downloaded bundle"
                        next_version
                        status.version in
                    Lwt.return @@ true
                end
           );
           StateReached RebootRequired;
           StateReached GettingVersionInfo;
         ])
  in
  run_test_scenario expected_state_sequence init_state

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
                 happy_flow_test ());
           ] );
       ]
