open Lwt
open Sexplib.Std

let log_src = Logs.Src.create "health"

type state =
  | Pending
  | MarkingAsGood
  | Good
  | Bad of string
[@@deriving sexp]

let rec run ~systemd ~rauc ~set_state =
  let set state = set_state state; run ~systemd ~rauc ~set_state state in
  function
  | Pending ->
    begin
      (* Wait for 30 seconds *)
      let%lwt () = Lwt_unix.sleep 30.0 in

      let open Systemd in

      (* Check what system state as systemd reports *)
      match%lwt Systemd.Manager.get_system_state systemd with

      | Manager.Running ->
        (* and set system as good *)
        set MarkingAsGood

      | Manager.Starting ->
        (* Systemd is still starting up some stuff. We wait. Systemd will handle job timeout itself and change state in finite time. *)
        set Pending

      | system_state ->
        (* or bad... *)
        Bad (Format.sprintf "system state is %s"
               (system_state
                |> Manager.sexp_of_system_state
                |> Sexplib.Sexp.to_string_hum
               ))
        |> set

    end

  | MarkingAsGood ->
    (* Mark currently booted slot as "good" *)
    begin
      match%lwt
        Rauc.get_booted_slot rauc
        >>= Rauc.mark_good rauc
        |> Lwt_result.catch
      with
      | Ok () -> set Good
      | Error exn -> set (Bad ("Failed to mark system good: " ^ (Printexc.to_string exn)))
    end

  | Good ->
    (* this thread should not terminate, thus create a never ending task.

      TODO: do periodic system checks
    *)
    Lwt.task () |> fst

  | Bad msg ->
    let%lwt () = Logs_lwt.err ~src:log_src (fun m -> m "system health bad: %s" msg) in
    (* TODO: mark system bad and exit *)
    set Pending

let start ~systemd ~rauc =
  let state_s, set_state = Lwt_react.S.create Pending in
  state_s, run ~systemd ~rauc ~set_state Pending
