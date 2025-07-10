let log_src = Logs.Src.create "watchdog"

let watchdog_service_name = "playos-network-watchdog.service"

let watchdog_disable_filepath =
  "/home/play/.config/playos-network-watchdog/disabled"

let is_disabled () = Lwt_unix.file_exists watchdog_disable_filepath

let enable systemd =
  let%lwt exists = Lwt_unix.file_exists watchdog_disable_filepath in
  let%lwt () =
    if exists then Lwt_unix.unlink watchdog_disable_filepath else Lwt.return ()
  in
  Systemd.Manager.start_unit systemd watchdog_service_name

let disable systemd =
  let%lwt () = Systemd.Manager.stop_unit systemd watchdog_service_name in
  let%lwt () = Util.ensure_parent_dir watchdog_disable_filepath in
  Util.write_to_file log_src watchdog_disable_filepath ""
