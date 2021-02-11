open Lwt
open Sexplib.Std

type label =
  { machine_id: string
  ; mac_1: string
  ; mac_2: string
  }
[@@deriving sexp]

let json_of_label label =
  Ezjsonm.dict [
    "machine-id", label.machine_id |> Ezjsonm.string
  ; "mac-1", label.mac_1 |> Ezjsonm.string
  ; "mac-2", label.mac_2 |> Ezjsonm.string
  ]

let print ~url label =
  let body =
    label
    |> json_of_label
    |> Ezjsonm.to_string
  in
  match%lwt
    Curl.request
      ~headers:[("Content-Type", "application/json")]
      ~data:body
      (url ^ "/print" |> Uri.of_string)
  with
  | RequestSuccess _ ->
      return ()
  | RequestFailure error ->
      Lwt.fail_with (Printf.sprintf "could not print label (%s)" (Curl.pretty_print_error error))
