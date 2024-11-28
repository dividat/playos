open Lwt

let main debug port =
  Logs.set_reporter (Logging.reporter ()) ;
  if debug then Logs.set_level (Some Logs.Debug)
  else Logs.set_level (Some Logs.Info) ;
  let%lwt server_info = Info.get () in
  let%lwt () =
    Logs_lwt.info (fun m ->
        m "PlayOS Controller Daemon (%s)" server_info.version
    )
  in
  (* Connect with systemd *)
  let%lwt systemd = Systemd.Manager.connect () in
  (* Connect with RAUC *)
  let%lwt rauc = Rauc.daemon () in
  let health_s, health_p = Health.start ~systemd ~rauc in
  (* Log changes in health state *)
  let%lwt () =
    Lwt_react.S.(
      map_s
        (fun state ->
          Logs_lwt.info (fun m ->
              m "health: %s"
                (state |> Health.sexp_of_state |> Sexplib.Sexp.to_string_hum)
          )
        )
        health_s
      >|= keep
    )
  in
  (* Connect with ConnMan *)
  let%lwt connman = Connman.Manager.connect () in
  (* Start the update mechanism *)
  let update_s, update_p = Update.start ~connman ~rauc in
  (* Log changes in update mechanism state *)
  let%lwt () =
    Lwt_react.S.(
      map_s
        (fun state ->
          Logs_lwt.info (fun m ->
              m "update mechanism: %s"
                (state |> Update.sexp_of_state |> Sexplib.Sexp.to_string_hum)
          )
        )
        update_s
      >|= keep
    )
  in
  (* Start the GUI *)
  let gui_p = Gui.start ~systemd ~port ~rauc ~connman ~update_s ~health_s in
  let%lwt () =
    (* Initialize Network, parallel to starting server *)
    ( match%lwt Network.init ~connman with
    | Ok () ->
        return_unit
    | Error exn ->
        Logs_lwt.warn (fun m ->
            m "network initialization failed: %s" (Printexc.to_string exn)
        )
    )
    <&> Lwt.pick
          [ (* Make sure all threads run forever. *)
            gui_p (* GUI *)
          ; update_p (* Update mechanism *)
          ; health_p (* Health monitoring *)
          ]
  in
  Logs_lwt.info (fun m -> m "terminating")

let () =
  let open Cmdliner in
  let debug_a =
    Arg.(flag (info ~doc:"Enable debug output." [ "d"; "debug" ]) |> value)
  in
  let port_a =
    Arg.(
      opt int 3333
        (info ~doc:"Port on which to start gui (http server)." ~docv:"PORT"
           [ "p"; "port" ]
        )
      |> value
    )
  in
  let main_t =
    Term.(const main $ debug_a $ port_a |> app (const Lwt_main.run))
  in
  main_t
  |> Cmd.v
       (Cmd.info ~doc:"PlayOS Controller" ~version:Info.version
          "playos-controller"
       )
  |> Cmd.eval
  |> ignore
