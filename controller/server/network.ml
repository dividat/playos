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

  match%lwt enable_and_scan_wifi_devices ~connman with

  | Ok () ->
    Lwt_result.return ()

  | Error exn ->
    let%lwt () = Logs_lwt.warn
        (fun m -> m "enabling and scanning wifi failed: %s, %s"
            (OBus_error.name exn)
            (Printexc.to_string exn))
    in
    Lwt_result.fail exn

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
