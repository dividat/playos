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

let print ~proxy ~url label =
  let open Cohttp in
  let open Cohttp_lwt_unix in
  let uri = url ^ "/print" |> Uri.of_string in
  let headers =
    Header.add (Header.init ()) "Content-Type" "application/json"
  in
  let body =
    label
    |> json_of_label
    |> Ezjsonm.to_string
    |> Cohttp_lwt.Body.of_string
  in
  Client.post ?proxy ~body ~headers uri
  >>= (fun (response,body) ->
      if response |> Response.status |> Code.code_of_status |> Code.is_success then
        return ()
      else
        let%lwt body_string = body |> Cohttp_lwt.Body.to_string in
        (response, body_string)
        |> [%sexp_of: Response.t * string]
        |> Sexplib.Sexp.to_string_hum
        |> (fun m -> Failure m)
        |> fail
    )
