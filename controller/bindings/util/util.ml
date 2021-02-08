open Lwt

let read_from_file log_src path =
  let%lwt exists = Lwt_unix.file_exists path in
  if exists then
    try
      let%lwt in_chan = Lwt_io.(open_file ~mode:Lwt_io.Input) path in
      let%lwt contents = Lwt_io.read in_chan >|= String.trim in
      let%lwt () = Lwt_io.close in_chan in
      return contents
    with
    | (Unix.Unix_error (err, fn, _)) as exn ->
      let%lwt () = Logs_lwt.err ~src:log_src
        (fun m -> m "failed to read from %s: %s" path (Unix.error_message err))
      in
      fail exn
    | exn ->
      fail exn
  else
    fail (Failure ("File does not exist: " ^ path))

let write_to_file log_src path str =
  try
    let%lwt fd =
      Lwt_unix.openfile path [ O_WRONLY; O_CREAT; O_TRUNC ] 0o755
    in
    let%lwt bytes_written =
      Lwt_unix.write_string fd str 0 (String.length str)
    in
    Lwt_unix.close fd
  with
  | (Unix.Unix_error (err, fn, _)) as exn ->
    let%lwt () = Logs_lwt.err ~src:log_src
      (fun m -> m "failed to write to %s: %s" path (Unix.error_message err))
    in
    fail exn
  | exn ->
    fail exn
