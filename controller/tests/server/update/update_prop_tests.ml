module Helpers = Update_test_helpers.Helpers

(* Converts a (random) sequence of bool elements into a
   function that on n-th invocation returns the n-th element, which indicates
   whether to inject ([true]) a failure or not ([false]).
   On n+1th and subsequent invocations always returns [false].
   Thread safe. *)
let failure_seq_to_f seq =
  let a = Array.of_list seq in
  let l = List.length seq in
  let c_mvar = Lwt_mvar.create 0 in
  fun () ->
    let%lwt c = Lwt_mvar.take c_mvar in
    let v = Array.get a c in
    let%lwt () = Lwt_mvar.put c_mvar (c + 1) in
    if c < l then Lwt.return v else Lwt.return false

(* Configures mocks to randomly fail and tests whether UpdateService gracefully
   handles them and always goes back to the initial (`GettingVersionInfo`)
   state.

   Failures are modeled as randomly injected exceptions, which are determined
   from a boolean sequence that indicates whether the n-th call should raise
   an exception ar not.

   Note: in theory there is some potential for non-determinism that can lead to
   non-reproducible scenarios, because if two asynchronous (Lwt) calls are made
   at the same time there is no ordering guarantee. However, UpdateService
   code is mostly "linear" Lwt.binds, so this should not happen in practice.
*)
let test_random_failure_case =
  let max_failures = QCheck2.Gen.pure 10 in
  let rand_failure_sequence_upd_client =
    QCheck2.Gen.(list_size max_failures bool)
  in
  let rand_failure_sequence_rauc = QCheck2.Gen.(list_size max_failures bool) in
  let rand_spec =
    QCheck2.Gen.(no_shrink @@ oneofl Helpers.all_possible_slot_spec_combos)
  in
  let gen =
    QCheck2.Gen.triple rand_failure_sequence_upd_client
      rand_failure_sequence_rauc rand_spec
  in
  let print_t (seq_upd, seq_rauc, inp_case) =
    let fail_seq_to_str seq =
      List.map (function true -> "x" | false -> "_") seq |> String.concat ""
    in
    let test_case_descr = Helpers.slot_spec_to_string inp_case in
    Format.sprintf
      "System setup: %s\n\
       Injected Update Client failures (%d): %s\n\
       Injected RAUC failures (%d): %s\n"
      test_case_descr
      (List.length @@ List.filter Fun.id seq_upd)
      (fail_seq_to_str seq_upd)
      (List.length @@ List.filter Fun.id seq_rauc)
      (fail_seq_to_str seq_rauc)
  in
  let test_check (seq_upd, seq_rauc, inp_case) =
    let failure_gen_upd = failure_seq_to_f seq_upd in
    let failure_gen_rauc = failure_seq_to_f seq_rauc in
    let test_config =
      { Update.http_error_backoff_duration = 0.001
      ; Update.install_error_backoff_duration = 0.002
      ; Update.check_for_updates_interval = 0.002
      }
    in
    let mocks =
      Helpers.init_test_deps ~failure_gen_upd ~failure_gen_rauc ~test_config ()
    in
    let () = Helpers.setup_mocks_from_system_slot_spec mocks inp_case in
    let module UpdateServiceI = (val mocks.update_service) in
    let () = Printexc.record_backtrace true in
    let run s =
      Lwt_main.run @@ Lwt_result.catch (fun () -> UpdateServiceI.run_step s)
    in
    let state_seq = Queue.create () in
    let state_seq_to_str state_seq =
      String.concat " -> "
      @@ List.map Helpers.statefmt
      @@ List.of_seq (Queue.to_seq state_seq)
    in
    let rec do_while ?(c = 0) loop_lim cur_state =
      Queue.push cur_state state_seq ;
      let out = run cur_state in
      match out with
      | Error e ->
          QCheck2.Test.fail_reportf
            "Update Service crashed (possibly due to an injected exception), \
             see specified source code line in the backtrace for the callsite \
             which caused the crash:\n\
             Exception: %s\n\
             Backtace: %s\n\
             State sequence: %s -> exception\n"
            (Printexc.to_string e)
            (Printexc.get_backtrace ())
            (state_seq_to_str state_seq)
      | Ok ({ process_state = Update.GettingVersionInfo; _ } as state) ->
          Queue.push state state_seq ; true
      | Ok state ->
          if c < loop_lim then do_while ~c:(c + 1) loop_lim state
          else
            QCheck2.Test.fail_reportf
              "Did not reach GettingVersionInfo in %d iterations, state \
               transitions:\n\
               %s\n"
              loop_lim
              (state_seq_to_str state_seq)
    in
    do_while 5 Update.initial_state
  in
  QCheck2.Test.make ~count:10_000 ~name:"UpdateService never crashes"
    ~print:print_t gen test_check

let () =
  let argv_with_verbose = Array.append Sys.argv [| "--verbose" |] in
  Alcotest.run ~argv:argv_with_verbose ~and_exit:false
    "UpdateService qcheck/prop tests"
    [ ( "Fault injection test"
      , [ QCheck_alcotest.to_alcotest ~verbose:true ~long:true
            test_random_failure_case
        ]
      )
    ]
