open Lwt

(* Require the resource directory to be at a directory fixed to the binary
 * location. This is not optimal, but works for the moment. *)
let resource_path end_path =
  let open Fpath in
  (Sys.argv.(0) |> v |> parent) / ".." / "share" // end_path |> to_string

let read_from_file log_src path =
  let%lwt exists = Lwt_unix.file_exists path in
  if exists then
    try
      let%lwt in_chan = Lwt_io.(open_file ~mode:Lwt_io.Input) path in
      let%lwt contents = Lwt_io.read in_chan >|= String.trim in
      let%lwt () = Lwt_io.close in_chan in
      return contents
    with
    | Unix.Unix_error (err, _fn, _) as exn ->
        let%lwt () =
          Logs_lwt.err ~src:log_src (fun m ->
              m "failed to read from %s: %s" path (Unix.error_message err)
          )
        in
        fail exn
    | exn ->
        let%lwt () =
          Logs_lwt.err ~src:log_src (fun m ->
              m "failed to read from %s: %s" path (Printexc.to_string exn)
          )
        in
        fail exn
  else fail (Failure ("File does not exist: " ^ path))

let write_to_file log_src path str =
  try
    let%lwt fd = Lwt_unix.openfile path [ O_WRONLY; O_CREAT; O_TRUNC ] 0o755 in
    let%lwt _bytes_written =
      Lwt_unix.write_string fd str 0 (String.length str)
    in
    Lwt_unix.close fd
  with
  | Unix.Unix_error (err, _fn, _) as exn ->
      let%lwt () =
        Logs_lwt.err ~src:log_src (fun m ->
            m "failed to write to %s: %s" path (Unix.error_message err)
        )
      in
      fail exn
  | exn ->
      let%lwt () =
        Logs_lwt.err ~src:log_src (fun m ->
            m "failed to write to %s: %s" path (Printexc.to_string exn)
        )
      in
      fail exn

let run_cmd_no_stdout cmd =
  match%lwt Lwt_process.(exec ~stdout:`Dev_null ~stderr:`Keep ("", cmd)) with
  | Unix.WEXITED 0 ->
      return_unit
  | _ ->
      Lwt.fail_with (Format.sprintf "%s failed" cmd.(0))

(* Equivalent of `mkdir -p $(dirname $path)` *)
let rec ensure_parent_dir ?(permissions = 0o755) path =
  let basedir = String.sub path 0 (String.rindex path '/') in
  let%lwt basedir_exists = Lwt_unix.file_exists basedir in
  if basedir_exists then Lwt.return ()
  else
    let%lwt () = ensure_parent_dir basedir ~permissions in
    Lwt_unix.mkdir basedir permissions
