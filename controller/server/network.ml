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


(* Hack to fix No Carrier error (https://01.org/jira/browse/CM-670) *)
let no_carrier_hack ~systemd ~connman =
  let%lwt () = Logs_lwt.info (fun m -> m "restarting wpa_supplicatn") in
  let%lwt () = Lwt_unix.sleep 3.0 in
  Lwt_result.(
    Systemd.Manager.restart_unit systemd "wpa_supplicant.service" |> Lwt_result.catch
    >>= (fun () -> Lwt_unix.sleep 3.0 |> Lwt_result.catch)
    >>= (fun () -> enable_and_scan_wifi_devices ~connman)
  )

let init ~systemd ~connman =
  let%lwt () = Logs_lwt.info (fun m -> m "initializing network connections") in

  match%lwt enable_and_scan_wifi_devices ~connman with

  | Ok () ->
    Lwt_result.return ()

  | Error exn ->
    let%lwt () = Logs_lwt.warn
        (fun m -> m "enabling and scanning wifi failed: %s, %s"
            (OBus_error.name exn)
            (Printexc.to_string exn))
    in
    no_carrier_hack ~systemd ~connman

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

module Interface = struct

  type t =
    { index: int
    ; name: string
    ; address: string
    ; link_type: string
    }
  [@@deriving sexp]

  let to_json i =
    Ezjsonm.(dict [
        "index", i.index |> int
      ; "name", i.name |> string
      ; "address", i.address |> string
      ; "link_type", i.link_type |> string
      ] |> value)

  let of_json j =
    let dict = Ezjsonm.get_dict j in
    { index = dict |> List.assoc "ifindex" |> Ezjsonm.get_int
    ; name = dict |> List.assoc "ifname" |> Ezjsonm.get_string
    ; address = dict |> List.assoc "address" |> Ezjsonm.get_string
    ; link_type = dict |> List.assoc "link_type" |> Ezjsonm.get_string
    }

  let get_all () =
    let command = "/run/current-system/sw/bin/ip", [| "ip"; "-j"; "link" |] in
    let%lwt json = Lwt_process.pread command in
    json
    |> Ezjsonm.from_string
    |> Ezjsonm.value
    |> Ezjsonm.get_list of_json
    |> return

end
