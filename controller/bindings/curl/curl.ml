type error =
  | UnsuccessfulStatus of int * string
  | UnreadableStatus of string
  | ProcessExit of int * string
  | ProcessKill of int
  | ProcessStop of int

let pretty_print_error error =
  match error with
  | UnsuccessfulStatus (code, body) ->
      Printf.sprintf "unsuccessful status %d: %s" code body

  | UnreadableStatus body ->
      Printf.sprintf "unreadable status code %s" body

  | ProcessExit (_, err) ->
      String.trim err

  | ProcessKill n ->
      Printf.sprintf "curl killed by signal %d" n

  | ProcessStop n ->
      Printf.sprintf "curl stopped by signal %d" n

type result =
  | RequestSuccess of int * string
  | RequestFailure of error

let exec cmd =
  let stdout_r, stdout_w = Unix.pipe () in
  let stderr_r, stderr_w = Unix.pipe () in
  let%lwt result =
    Lwt_process.exec
      ~stdout:(`FD_move stdout_w)
      ~stderr:(`FD_move stderr_w)
      cmd
  in
  let stdout_input = Lwt_io.of_unix_fd ~mode:Lwt_io.input stdout_r in
  let stderr_input = Lwt_io.of_unix_fd ~mode:Lwt_io.input stderr_r in
  let%lwt stdout = Lwt_io.read stdout_input in
  let%lwt stderr = Lwt_io.read stderr_input in
  Lwt.return (result, stdout, stderr)

let safe_int_of_string str =
  try
    Some (int_of_string str)
  with
    Failure _ -> None

let http_code_marker = '|'

let parse_status_code_and_body str =
  let open Base.Option in
  Base.String.rsplit2 ~on:http_code_marker str >>= fun (body, code_str) ->
  safe_int_of_string code_str >>= fun code ->
  return (code, body)

let request ?proxy ?(headers = []) ?data ?(options = []) url =
  let cmd =
    "/run/current-system/sw/bin/curl",
    (Array.concat
      [ [| "curl"; Uri.to_string url
         ; "--silent"
         ; "--show-error"
         ; "--write-out"; Char.escaped http_code_marker ^ "%{http_code}"
        |]
      ; (match proxy with
        | Some p ->
            [| "--proxy"
            ;  Proxy.to_string ~hide_password:false p
            ;  "--proxy-anyauth"
            |]
        | None -> [| |])
      ; (headers
          |> List.map (fun (k, v) -> [| "--header"; (k ^ ":" ^ v) |])
          |> Array.concat)
      ; (match data with
        | Some d -> [| "--data"; d |]
        | None -> [| |])
      ; Base.List.to_array options
      ])
  in
  match%lwt exec cmd with
  | (Unix.WEXITED 0, stdout, _) ->
      (match parse_status_code_and_body stdout with
      | Some (code, body) ->
          if Cohttp.Code.is_success code then
            Lwt.return (RequestSuccess (code, body))
          else
            Lwt.return (RequestFailure (UnsuccessfulStatus (code, body)))
      | None ->
          Lwt.return (RequestFailure (UnreadableStatus stdout)))

  | (Unix.WEXITED n, _, stderr) ->
      Lwt.return (RequestFailure (ProcessExit (n, stderr)))

  | (Unix.WSIGNALED signal, _, stderr) ->
      Lwt.return (RequestFailure (ProcessKill signal))

  | (Unix.WSTOPPED signal, _, stderr) ->
      Lwt.return (RequestFailure (ProcessStop signal))
