open Lwt
open Sexplib.Std

let log_src = Logs.Src.create "network"

let enable_and_scan_wifi_devices ~connman =
  begin
    let open Connman in
    (* Get all available technolgies *)
    let%lwt technologies = Manager.get_technologies connman in

    (* enable all wifi devices *)
    let%lwt () =
      technologies
      |> List.filter (fun (t:Technology.t) ->
          t.type' = Technology.Wifi && not t.powered)
      |> List.map (Technology.enable)
      |> Lwt.join
    in

    (* and start a scan. *)
    let%lwt () =
      technologies
      |> List.filter (fun (t:Technology.t) -> t.type' = Technology.Wifi)
      |> List.map (Technology.scan)
      |> Lwt.join
    in

    return_unit
  end
  (* Add a timeout to scan *)
  |> (fun p -> [p; Lwt_unix.timeout 30.0] |> Lwt.pick)
  |> Lwt_result.catch


let init ~systemd ~connman =
  let%lwt () = Logs_lwt.info (fun m -> m "initializing network connections") in

  enable_and_scan_wifi_devices ~connman
  >>= CCResult.(
      catch
        ~ok:(fun x -> x |> return |> Lwt.return)
        ~err:(fun exn ->
            let%lwt () = Logs_lwt.warn
                (fun m -> m "enabling and scanning wifi failed: %s, %s"
                    (OBus_error.name exn)
                    (Printexc.to_string exn))
            in
            (* Hack to fix No Carrier error (https://01.org/jira/browse/CM-670) *)
            let%lwt () = Logs_lwt.info (fun m -> m "restarting wpa_supplicatn") in
            let%lwt () = Systemd.Manager.restart_unit systemd "wpa_supplicant.service" in
            let%lwt () = Lwt_unix.sleep 3.0 in
            enable_and_scan_wifi_devices ~connman
          )
    )

module Internet =
struct

  type state =
    | Pending
    | Connected
    | NotConnected of string
  [@@deriving sexp]

  let http_check () =
    let open Cohttp in
    let open Cohttp_lwt_unix in
    let%lwt () = Logs_lwt.debug ~src:log_src (fun m -> m "checking internet connectivity with HTTP.") in
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

  let rec check_loop
      ~update_state
      ~(network_change:unit Lwt_react.E.t)
      ~(retry_timeout:float)
    =
    let open Lwt_react in

    (* wait for network change or retry timeout *)
    let%lwt () =
      [ network_change |> E.next
      ; Lwt_unix.sleep retry_timeout
      ] |> Lwt.pick
    in

    (* get new state *)
    let%lwt new_state = http_check () in

    (* helper to update and set timeout *)
    let update timeout s =
      update_state s;
      check_loop ~update_state ~network_change ~retry_timeout:timeout
    in

    match new_state with
    | Connected ->
      (* if connected only recheck in 10 minutes *)
      update (10. *. 60.) Connected
    | NotConnected _ ->
      (* if not Connected recheck in 5 seconds *)
      update 5. new_state
    | Pending ->
      (* this should never happen *)
      update 5. new_state

  let get connman =
    let open Lwt_react in
    let%lwt network_change =
      Connman.Manager.get_services_signal connman
      >|= S.changes
      >|= E.map ignore (* don't care how the services changed *)
    in
    let state, update_state = S.create (Pending) in
    return (state, check_loop ~update_state ~network_change  ~retry_timeout:5.0)

  let is_connected = function
    | Pending -> false
    | Connected -> true
    | NotConnected _ -> false

end
