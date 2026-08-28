open Lwt
open Sexplib.Std
open Protocol_conv_jsonm

let log_src = Logs.Src.create "network"

let enable_and_scan_wifi_devices ~connman =
  Lwt_result.catch (fun () ->
      (let open Connman in
       (* Get all available technolgies *)
       let%lwt technologies = Manager.get_technologies connman in
       (* enable all wifi devices *)
       let%lwt () =
         technologies
         |> List.filter (fun (t : Technology.t) ->
             t.type' = Technology.Wifi && not t.powered
         )
         |> List.map Technology.enable
         |> Lwt.join
       in
       (* and start a scan. *)
       let%lwt () =
         technologies
         |> List.filter (fun (t : Technology.t) -> t.type' = Technology.Wifi)
         |> List.map Technology.scan
         |> Lwt.join
       in
       return_unit
      )
      (* Add a timeout to scan *)
      |> fun p -> [ p; Lwt_unix.timeout 30.0 ] |> Lwt.pick
  )

let init ~connman =
  let%lwt () =
    Logs_lwt.info ~src:log_src (fun m -> m "initializing network connections")
  in
  match%lwt enable_and_scan_wifi_devices ~connman with
  | Ok () ->
      Lwt_result.return ()
  | Error exn ->
      let%lwt () =
        Logs_lwt.warn ~src:log_src (fun m ->
            m "enabling and scanning wifi failed: %s, %s" (OBus_error.name exn)
              (Printexc.to_string exn)
        )
      in
      Lwt_result.fail exn

(** A partial classification of interfaces *)
type interface_kind =
  | Loopback
  | Ethernet
  | Wireless
  | Other
[@@deriving sexp]

module Interface = struct
  type t =
    { index : int
    ; name : string
    ; address : string
    ; link_type : string
    ; link_status : string
    }
  [@@deriving sexp, protocol ~driver:(module Jsonm)]

  let to_json i =
    Ezjsonm.(
      dict
        [ ("index", i.index |> int)
        ; ("name", i.name |> string)
        ; ("address", i.address |> string)
        ; ("link_type", i.link_type |> string)
        ; ("link_status", i.link_status |> string)
        ]
      |> value
    )

  let of_json j =
    try
      let dict = Ezjsonm.get_dict j in
      Some
        { index = dict |> List.assoc "ifindex" |> Ezjsonm.get_int
        ; name = dict |> List.assoc "ifname" |> Ezjsonm.get_string
        ; address = dict |> List.assoc "address" |> Ezjsonm.get_string
        ; link_type = dict |> List.assoc "link_type" |> Ezjsonm.get_string
        ; link_status = dict |> List.assoc "operstate" |> Ezjsonm.get_string
        }
    with _ -> None

  (** Get a list of network interfaces.

      NOTE `ip link` can output varying fields depending on link type.
      Interfaces with missing fields are omitted from the list, as we are only
      interested in link types where all fields are present (Ethernet, WLAN).

  *)
  let get_all () =
    let command = ("", [| "ip"; "-j"; "link" |]) in
    let%lwt json = Lwt_process.pread command in
    json
    |> Ezjsonm.from_string
    |> Ezjsonm.value
    |> Ezjsonm.get_list of_json
    |> List.filter_map (fun x -> x)
    |> return

  let prefix_to_kind = [ ("eth", Ethernet); ("en", Ethernet); ("wl", Wireless) ]

  let kind t =
    if t.link_type = "loopback" then Loopback
    else
      prefix_to_kind
      |> List.find_opt (fun (prefix, _) -> String.starts_with ~prefix t.name)
      |> Option.map snd
      |> Option.value ~default:Other
end
