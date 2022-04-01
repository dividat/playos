open Fun

type credentials =
  { user: string
  ; password: string
  }

type t =
  { credentials: credentials option
  ; host: string
  ; port: int
  }

let make ?user ?password host port =
  { host = host
  ; port = port
  ; credentials =
    (match user, password with
    | Some u, Some p -> Some { user = u; password = p }
    | _ -> None)
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
          | Some user, Some password -> Some { user = Uri.pct_decode user; password = Uri.pct_decode password }
          | _ -> None)
        ; host
        ; port
        }
    | _ -> None
  else
    None

let to_string ~hide_password t =
  let escape_userinfo = Uri.pct_encode ~component:`Userinfo in
  let
    userinfo =
      Option.map
        (fun credentials ->
          escape_userinfo credentials.user
            ^ ":"
            ^ if hide_password then "******" else escape_userinfo credentials.password
        )
        t.credentials
  in
  Uri.empty
  |> flip Uri.with_scheme (Some "http")
  |> flip Uri.with_host (Some t.host)
  |> flip Uri.with_port (Some t.port)
  |> flip Uri.with_userinfo userinfo
  |> Uri.to_string

(* Extract the proxy from the default route.
 *
 * The service with the default route will always be sorted at the top of the
 * list. (From connman doc/overview-api.txt *)
let from_default_service services =
  let open Connman.Service in
  List.find_opt (fun s -> s.state = Online || s.state == Ready) services
    |> Base.Fn.flip Option.bind (fun s -> s.proxy)
    |> Base.Fn.flip Option.bind validate
