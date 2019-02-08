open Lwt
open Sexplib.Std

module Internet =
struct

  type state =
    | Connected
    | NotConnected of string
  [@@deriving sexp]

  let check () =
    let open Cohttp in
    let open Cohttp_lwt_unix in
    match%lwt
      Client.get (Uri.of_string
                    (* Note that we use http to circumvent https://github.com/mirage/ocaml-cohttp/issues/130.

                       The expected response is 301 Moved Permanently (to the https address), which is sufficient for checking internet connectivity.
                    *)
                    "http://api.dividat.com/")
      |> Lwt_result.catch
    with
    | Ok _ ->
      Connected |> return
    | Error exn ->
      NotConnected (Printexc.to_string exn) |> return

  (* [check_patiently n] checks connection but retries [n] times if state is NotConnected.

     This adds a delay when changing state to NotConnected and accommodates a delay between network change and Internet connectivity.
  *)
  let rec check_patiently remaining_tries old_state =
    let%lwt new_state = check () in
    match remaining_tries > 0, new_state with
    | _, Connected ->
      return Connected (* immediately return when connected *)
    | true, NotConnected msg ->
      let%lwt () = Lwt_unix.sleep 5.0 in
      check_patiently (remaining_tries-1) old_state
    | false, NotConnected msg ->
      return new_state

  let get_state connman =
    let open Lwt_react in
    let%lwt network_change =
      Connman.Manager.get_services_signal connman
      >|= S.changes
      >|= E.map ignore (* don't care how the services changed *)
    in
    let%lwt initial_state = check_patiently 3 (NotConnected "init") in
    S.accum_s (network_change |> E.map (fun _ -> check_patiently 3)) initial_state
    |> return

  let is_connected = function
    | Connected -> true
    | NotConnected _ -> false

end
