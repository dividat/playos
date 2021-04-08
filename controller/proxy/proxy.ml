type credentials =
  { user: string
  ; password: string
  }

type t =
  { credentials: credentials option
  ; host: string
  ; port: int
  }

let validate str =
  let uri = Uri.of_string str in
  if Uri.path uri = ""
    && Uri.query uri = []
    && Uri.fragment uri = None
  then
    match Uri.scheme uri, Uri.host uri, Uri.port uri with
    | Some "http", Some host, Some port ->
      Some
        { credentials =
          (match Uri.user uri, Uri.password uri with
          | Some user, Some password -> Some { user; password }
          | _ -> None)
        ; host
        ; port
        }
    | _ -> None
  else
    None

let to_string ~hide_password t =
  [ "http://"
  ; (match t.credentials with
    | Some credentials ->
        [ credentials.user
        ; ":"
        ; if hide_password then "******" else credentials.password
        ; "@"
        ]
        |> String.concat ""
    | None -> "")
  ; t.host
  ; ":"
  ; string_of_int t.port
  ]
  |> String.concat ""

(* Extract the proxy from the default route.
 *
 * The service with the default route will always be sorted at the top of the
 * list. (From connman doc/overview-api.txt *)
let from_default_service services =
  let open Connman.Service in
  List.find_opt (fun s -> s.state = Online || s.state == Ready) services
    |> Base.Fn.flip Option.bind (fun s -> s.proxy)
    |> Base.Fn.flip Option.bind validate
