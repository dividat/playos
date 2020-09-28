open Lwt
open Sexplib.Std

let shutdown () =
  match%lwt
    Lwt_process.(exec
                   ~stdout:`Dev_null
                   ~stderr:`Keep
                   ("", [|"halt"; "--poweroff"|])
                )
  with
  | Unix.WEXITED 0 ->
    return_unit
  | _ ->
    Lwt.fail_with (Format.sprintf "shutdown failed")

let get_proxy_from_pacrunner () =
  let command = "/run/current-system/sw/bin/pacproxy", [| "pacproxy" |] in
  let%lwt proxy = Lwt_process.pread command >|= String.trim in
  if proxy = "" then
    return None
  else
    return (Some (Uri.of_string ("http://" ^ proxy)))

let main debug port =
  Logs.set_reporter (Logging.reporter ());

  if debug then
    Logs.set_level (Some Logs.Debug)
  else
    Logs.set_level (Some Logs.Info);

  let%lwt proxy = get_proxy_from_pacrunner () in

  let%lwt server_info = Info.get ~proxy in

  let%lwt () =
    Logs_lwt.info (fun m -> m "PlayOS Controller Daemon (%s)" server_info.version)
  in

  let%lwt () =
    match proxy with
    | Some p -> Logs_lwt.info (fun m -> m "proxy: %s" (Uri.to_string p))
    | None -> Logs_lwt.info (fun m -> m "proxy: none")
  in

  (* Connect with systemd *)
  let%lwt systemd = Systemd.Manager.connect () in

  (* Connect with RAUC *)
  let%lwt rauc = Rauc.daemon () in

  let health_s, health_p = Health.start ~systemd ~rauc in

  (* Log changes in health state *)
  let%lwt () =
    Lwt_react.S.(
      map_s (fun state -> Logs_lwt.info (fun m -> m "health: %s"
                                            (state
                                             |> Health.sexp_of_state
                                             |> Sexplib.Sexp.to_string_hum)
                                        )) health_s
      >|= keep
    )
  in

  (* Connect with ConnMan *)
  let%lwt connman = Connman.Manager.connect () in

  (* Get Internet state *)
  let%lwt internet, internet_p = Network.Internet.get connman ~proxy in

  (* Log changes to Internet state *)
  let%lwt () =
    Lwt_react.S.(
      map_s (fun state -> Logs_lwt.info (fun m -> m "internet: %s"
                                            (state
                                             |> Network.Internet.sexp_of_state
                                             |> Sexplib.Sexp.to_string_hum)
                                        )) internet
      >|= keep
    )
  in

  (* Start the update mechanism *)
  let update_s, update_p = Update.start ~proxy ~rauc ~update_url:Info.update_url in

  (* Log changes in update mechanism state *)
  let%lwt () =
    Lwt_react.S.(
      map_s (fun state -> Logs_lwt.info (fun m -> m "update mechanism: %s"
                                            (state
                                             |> Update.sexp_of_state
                                             |> Sexplib.Sexp.to_string_hum)
                                        )) update_s
      >|= keep
    )
  in

  (* Start the GUI *)
  let gui_p =
    Gui.start
      ~port
      ~shutdown
      ~rauc
      ~connman
      ~internet
      ~update_s
      ~health_s
      ~proxy
  in

  let%lwt () =
    (* Initialize Network, parallel to starting server *)
    begin
      match%lwt Network.init ~systemd ~connman with
      | Ok () ->
        return_unit
      | Error exn ->
        Logs_lwt.warn (fun m -> m "network initialization failed: %s" (Printexc.to_string exn))
    end

    <&> Lwt.pick [
      (* Make sure all threads run forever. *)
      gui_p (* GUI *)
    ; update_p (* Update mechanism *)
    ; health_p (* Health monitoring *)
    ; internet_p (* Internet connectivity check *)
    ]


  in

  Logs_lwt.info (fun m -> m "terminating")

let () =
  let open Cmdliner in
  let debug_a = Arg.(flag
                       (info ~doc:"Enable debug output." ["d"; "debug"])
                     |> value)
  in
  let port_a = Arg.(opt int 3333
                      (info ~doc:"Port on which to start gui (http server)." ~docv:"PORT" ["p"; "port"])
                    |> value)
  in
  let main_t =
    Term.(
      const main
      $ debug_a
      $ port_a
      |> app (const Lwt_main.run)
    )
  in
  Term.(eval (main_t, Term.info ~doc:"PlayOS Controller" ~version:Info.version "playos-controller"))
  |> ignore
