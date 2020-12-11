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
