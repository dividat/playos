open Lwt
open Sexplib.Std

let shutdown () =
  match%lwt
    Lwt_process.(exec
                   ~stdout:`Dev_null
                   ~stderr:`Keep
                   ("", [|"halt"; "-p"; "-f"|])
                )
  with
  | Unix.WEXITED 0 ->
    return_unit
  | _ ->
    Lwt.fail_with (Format.sprintf "shutdown failed")


let server
    ~(rauc:Rauc.t)
    ~(connman:Connman.Manager.t)
    ~(internet:Network.Internet.state Lwt_react.S.t)
    ~(update_s: Update.state Lwt_react.signal) =
  Opium.App.(
    empty
    |> port 3333

    |> get "/" (fun _ ->
        Info.get ()
        >|= Info.to_json
        >|= (fun x -> `Json x)
        >|= respond)

    |> get "/shutdown" (fun _ ->
        shutdown ()
        >|= (fun _ -> `String "Ok")
        >|= respond
      )
    |> Gui.routes ~connman ~internet

    (* Following routes are for system debugging - they are currently not being used by GUI *)
    (* |> middleware (Opium.Middleware.debug) *)
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
    |> get "/network" (fun _ ->
        Connman.Manager.get_services connman
        >|= [%sexp_of: Connman.Service.t list]
        >|= Sexplib.Sexp.to_string_hum
        >|= (fun x -> `String x)
        >|= respond
      )
  )

let main update_url =
  Logs.set_reporter (Logging.reporter ());
  Logs.set_level (Some Logs.Info);

  let%lwt server_info = Info.get () in

  let%lwt () =
    Logs_lwt.info (fun m -> m "PlayOS Controller Daemon (%s)" server_info.version)
  in

  (* Connect with RAUC *)
  let%lwt rauc = Rauc.daemon () in

  let health_s, health_p = Health.start ~rauc in

  (* Log changes in health state *)
  let%lwt () =
    Lwt_react.S.(
      map_s (fun state -> Logs_lwt.info (fun m -> m "health: %s"
                                            (state
                                             |> Health.sexp_of_state
                                             |> Sexplib.Sexp.to_string)
                                        )) health_s
      >|= keep
    )
  in

  (* Connect with ConnMan *)
  let%lwt connman = Connman.Manager.connect () in

  (* Initialize Network *)
  let%lwt () = Network.init connman in

  (* Get Internet state *)
  let%lwt internet, internet_p = Network.Internet.get connman in

  (* Log changes to Internet state *)
  let%lwt () =
    Lwt_react.S.(
      map_s (fun state -> Logs_lwt.info (fun m -> m "internet: %s"
                                            (state
                                             |> Network.Internet.sexp_of_state
                                             |> Sexplib.Sexp.to_string)
                                        )) internet
      >|= keep
    )
  in

  (* Start the update mechanism *)
  let update_s, update_p = Update.start ~rauc ~update_url in

  (* Log changes in update mechanism state *)
  let%lwt () =
    Lwt_react.S.(
      map_s (fun state -> Logs_lwt.info (fun m -> m "update mechanism: %s"
                                            (state
                                             |> Update.sexp_of_state
                                             |> Sexplib.Sexp.to_string)
                                        )) update_s
      >|= keep
    )
  in

  (* Start HTTP server *)
  let server_p =
    server
      ~rauc
      ~connman
      ~internet
      ~update_s
    |> Opium.App.start
  in

  (* Make sure all threads run forever. *)
  let%lwt () =
    Lwt.pick [
      server_p (* HTTP server *)
    ; update_p (* Update mechanism *)
    ; health_p (* Health monitoring *)
    ; internet_p (* Internet connectivity check *)
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

