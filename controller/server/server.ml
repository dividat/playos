open Lwt

let server
    ~(rauc:Rauc.t)
    ~(update_s: Update.state Lwt_react.signal) =
  Opium.App.(
    empty
    |> port 3333
    |> get "/" (fun _ -> `Json Info.(get () |> to_json) |> respond')
    |> get "/rauc" (fun _ ->
        Rauc.get_status rauc
        >|= Rauc.sexp_of_status
        >|= Sexplib.Sexp.to_string_hum
        >|= (fun x -> `String x)
        >|= respond
      )
    |> get "/update" (fun _ ->
        update_s
        |> Lwt_react.S.value
        |> Update.sexp_of_state
        |> Sexplib.Sexp.to_string_hum
        |> (fun s -> `String s)
        |> respond'
      )
    |> Gui.routes
    |> middleware (Opium.Middleware.debug)
  )

let main update_url =
  Logs.set_reporter (Logging.reporter ());
  Logs.set_level (Some Logs.Debug);

  let%lwt () =
    let server_info = Info.get () in
    Logs_lwt.info (fun m -> m "PlayOS Controller Daemon (%s)" server_info.version)
  in

  (* Connect with RAUC *)
  let%lwt rauc = Rauc.daemon () in

  (* Mark currently booted slot as "good" *)
  let%lwt () = try%lwt
      Rauc.get_booted_slot rauc
      >>= Rauc.mark_good rauc
    with
    | exn ->
      Logs_lwt.err (fun m -> m "RAUC: %s" (Printexc.to_string exn))
  in

  let%lwt () = try%lwt
      Rauc.get_status rauc
      >|= Rauc.sexp_of_status
      >|= Sexplib.Sexp.to_string_hum
      >>= Lwt_io.printl
    with
    | exn ->
      Logs_lwt.err (fun m -> m "RAUC: %s" (Printexc.to_string exn))
  in

  let update_s, update_p = Update.start ~rauc ~update_url in

  (* All following promises should run forever. *)
  let%lwt () =
    Lwt.pick [
      server ~rauc ~update_s |> Opium.App.start
    ; update_p
    ]
  in

  Logs_lwt.info (fun m -> m "terminating")

let () =
  let open Cmdliner in
  (* command-line arguments *)
  let update_url_a =
    Arg.(required & pos 0 (some string) None & info []
           ~docv:"UPDATE_URL"
           ~doc:"URL from where updates should be retrieved"
        ) in
  let main_t =
    Term.(
      const Lwt_main.run
      $  (
        const main
        $ update_url_a
      )
    )
  in
  Term.(eval (main_t, Term.info ~doc:"PlayOS Controller" "playos-controller"))
  |> ignore

