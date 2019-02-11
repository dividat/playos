open Lwt
open Sexplib.Std

let log_src = Logs.Src.create "health"

type state =
  | Pending
  | MarkingAsGood
  | Good
  | Bad of string
[@@deriving sexp]


let mark_system_good ~rauc =
  (* Mark currently booted slot as "good" *)
  let%lwt () = Logs_lwt.info ~src:log_src (fun m -> m "marking system good") in
  Rauc.get_booted_slot rauc
  >>= Rauc.mark_good rauc
  |> Lwt_result.catch


let rec run ~rauc ~set_state =
  let set state = set_state state; run ~rauc ~set_state state in
  function
  | Pending ->
    (* Wait for 30 seconds *)
    let%lwt () = Lwt_unix.sleep 30.0 in

    (* and set system as good *)
    set MarkingAsGood

  | MarkingAsGood ->
    begin
      match%lwt mark_system_good ~rauc with
      | Ok () -> set Good
      | Error exn -> set (Bad ("Failed to mark system good: " ^ (Printexc.to_string exn)))
    end

  | Good ->
    (* this thread should not terminate, thus create a never ending task. *)
    Lwt.task () |> fst
    (* TODO: do periodic system checks *)

  | Bad msg ->
    let%lwt () = Logs_lwt.err ~src:log_src (fun m -> m "system health bad: %s" msg) in
    (* TODO: mark system bad and exit *)
    set Pending

let start ~rauc =
  let state_s, set_state = Lwt_react.S.create Pending in
  state_s, run ~rauc ~set_state Pending
