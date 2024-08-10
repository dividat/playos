open Lwt
open Sexplib.Conv

let log_src = Logs.Src.create "update"

let bundle_name =
  "@PLAYOS_BUNDLE_NAME@"

(* Version handling *)


(** Type containing version information *)
type version_info =
  {(* the latest available version *)
    latest : (Semver.t [@sexp.opaque]) * string

  (* version of currently booted system *)
  ; booted : (Semver.t [@sexp.opaque]) * string

  (* version of inactive system *)
  ; inactive : (Semver.t [@sexp.opaque]) * string
  }
[@@deriving sexp]

type state =
  | GettingVersionInfo
  | ErrorGettingVersionInfo of string
  | UpToDate of version_info
  | Downloading of {url: string; version: string}
  | ErrorDownloading of string
  | Installing of string
  | ErrorInstalling of string
  (* inactive system has been updated and reboot is required to boot into updated system *)
  | RebootRequired
  (* inactive system is up to date, but current system was selected for boot *)
  | OutOfDateVersionSelected
  (* there are no known-good systems and a reinstall is recommended *)
  | ReinstallRequired
[@@deriving sexp]

type sleep_duration = float (* seconds *)

type config = {
    error_backoff_duration: sleep_duration;
    check_for_updates_interval: sleep_duration;
    update_url: string
}

(** Helper to parse semver from string or fail *)
let semver_of_string string =
  let trimmed_string = String.trim string
  in
  match Semver.of_string trimmed_string with
  | None ->
    failwith
      (Format.sprintf "could not parse version (version string: %s)" string)
  | Some version ->
    version, trimmed_string


let bundle_file_name version =
  Format.sprintf "%s-%s.raucb" bundle_name version

(* TODO: FIX: this will produce an invalid URL if ~update_url is missing a
   trailing slash *)
(* TODO: Should probably be moved to config too *)
let latest_download_url ~update_url version_string =
  Format.sprintf "%s%s/%s" update_url version_string (bundle_file_name version_string)


module type ServiceDeps = sig
    module CurlI: Curl_proxy.CurlProxyInterface
    module RaucI: Rauc_service.RaucServiceIntf
    val config : config
end

module UpdateService(Deps : ServiceDeps) = struct
    open Deps

    let sleep_error_backoff =
        Lwt_unix.sleep config.error_backoff_duration

    let sleep_update_check =
        Lwt_unix.sleep config.check_for_updates_interval

    (** Get latest version available at [url] *)
    let get_latest_version url =
      match%lwt CurlI.request (Uri.of_string (url ^ "latest")) with
      | RequestSuccess (_, body) ->
          return (semver_of_string body)
      | RequestFailure error ->
          Lwt.fail_with (Printf.sprintf "could not get latest version (%s)" (Curl.pretty_print_error error))

    (** Get version information *)
    let get_version_info url =
      Lwt_result.catch
        (fun () ->
          let%lwt latest = get_latest_version url in
          let%lwt rauc_status = RaucI.get_status () in

          let system_a_version = rauc_status.a.version |> semver_of_string in
          let system_b_version = rauc_status.b.version |> semver_of_string in

          match%lwt RaucI.get_booted_slot () with
          | SystemA ->
            { latest = latest
            ; booted = system_a_version
            ; inactive = system_b_version
            }
            |> return
          | SystemB ->
            { latest = latest
            ; booted = system_b_version
            ; inactive = system_a_version
            }
            |> return
        )

    (** download RAUC bundle *)
    let download url version =
      let bundle_path = Format.sprintf "/tmp/%s" (bundle_file_name version) in
      let options =
        [ "--continue-at"; "-" (* resume download *)
        ; "--limit-rate"; "10M"
        ; "--output"; bundle_path
        ]
      in
      match%lwt CurlI.request ~options url with
      | RequestSuccess _ ->
          return bundle_path
      | RequestFailure error ->
          Lwt.fail_with (Printf.sprintf "could not download RAUC bundle (%s)" (Curl.pretty_print_error error))

(* Update mechanism process *)
    (** perform a single state transition from given state *)
    let run_step (state:state) : state Lwt.t =
       let set = Lwt.return in
       match (state) with
      | GettingVersionInfo ->
        (* get version information and decide what to do *)
        begin
          match%lwt get_version_info config.update_url with
          | Ok version_info ->

            (* Compare latest available version to version booted. *)
            let booted_version_compare = Semver.compare
                (fst version_info.latest)
                (fst version_info.booted) in
            let booted_up_to_date = booted_version_compare = 0 in

            (* Compare latest available version to version on inactive system partition. *)
            let inactive_version_compare = Semver.compare
                (fst version_info.latest)
                (fst version_info.inactive) in
            let inactive_up_to_date = inactive_version_compare = 0 in
            let inactive_update_available = inactive_version_compare > 0 in

            if booted_up_to_date || inactive_up_to_date then
              match%lwt RaucI.get_primary () with
              | Some primary_slot ->
                if booted_up_to_date then
                  (* Don't care if inactive can be updated. I.e. Only update the inactive partition once the booted partition is outdated. This results in always two versions being available on the machine. *)
                  UpToDate version_info |> set
                else
                  let%lwt booted_slot = RaucI.get_booted_slot () in
                  if booted_slot = primary_slot then
                    (* Inactive is up to date while booted is out of date, but booted was specifically selected for boot *)
                    OutOfDateVersionSelected |> set
                  else
                    (* If booted is not up to date but inactive is both up to date and primary, we should reboot into the primary *)
                    RebootRequired |> set
              | None ->
                (* All systems bad; suggest reinstallation *)
                ReinstallRequired |> set

            else if inactive_update_available then
              (* Booted system is not up to date and there is an update available for inactive system. *)
              let latest_version = version_info.latest |> snd in
              let url = latest_download_url ~update_url:config.update_url latest_version in
              Downloading {url = url; version = latest_version}
              |> set

            else
              let msg =
                ("nonsensical version information: "
                 ^ (version_info
                    |> sexp_of_version_info
                    |> Sexplib.Sexp.to_string_hum))
              in
              let%lwt () =
                Logs_lwt.warn ~src:log_src
                  (fun m -> m "%s" msg)
              in
              ErrorGettingVersionInfo msg |> set

          | Error exn ->
            ErrorGettingVersionInfo (Printexc.to_string exn)
            |> set
        end

      | ErrorGettingVersionInfo msg ->
        (* handle error while getting version information *)
        let%lwt () =
          Logs_lwt.err ~src:log_src
            (fun m -> m "failed to get version information: %s" msg)
        in
        (* sleep and retry *)
        let%lwt () = sleep_error_backoff in
        set GettingVersionInfo

      | Downloading {url; version} ->
        (* download latest version *)
        (match%lwt Lwt_result.catch (fun () -> download (Uri.of_string url) version) with
         | Ok bundle_path ->
           Installing bundle_path
           |> set
         | Error exn ->
           ErrorDownloading (Printexc.to_string exn)
           |> set
        )

      | ErrorDownloading msg ->
        (* handle error while downloading bundle *)
        let%lwt () =
          Logs_lwt.err ~src:log_src
            (fun m -> m "failed to download RAUC bundle: %s" msg)
        in
        (* sleep and retry *)
        let%lwt () = sleep_error_backoff in
        set GettingVersionInfo

      | Installing bundle_path ->
        (* install bundle via RAUC *)
        (match%lwt Lwt_result.catch (fun () -> RaucI.install bundle_path) with
         | Ok () ->
           let%lwt () =
             Logs_lwt.info (fun m -> m "succesfully installed update (%s)" bundle_path)
           in
           RebootRequired
           |> set
         | Error exn ->
           let () = try Sys.remove bundle_path with
             | _ -> ()
           in
           ErrorInstalling (Printexc.to_string exn)
           |> set
        )

      | ErrorInstalling msg ->
        (* handle installation error *)
        let%lwt () =
          Logs_lwt.err ~src:log_src
            (fun m -> m "failed to install RAUC bundle: %s" msg)
        in
        (* sleep and retry *)
        let%lwt () = sleep_error_backoff in
        set GettingVersionInfo

      | UpToDate _
      | RebootRequired
      | OutOfDateVersionSelected
      | ReinstallRequired ->
        (* sleep and recheck for new updates *)
        let%lwt () = sleep_update_check in
        set GettingVersionInfo

    (** Finite state machine handling updates *)
    let rec run ~set_state state =
      let%lwt next_state = run_step state in
        set_state state;
        run ~set_state next_state

    module Private = struct
        let run_step = run_step
    end
end

let build_config update_url : config = {
    update_url = update_url;
    error_backoff_duration = 30.0;
    check_for_updates_interval = (1. *. 60. *. 60.)
}

let build_deps ~connman ~(rauc : Rauc.t) ~(update_url : string) :
    (module ServiceDeps) Lwt.t =

  let config = build_config update_url in
  let raucI = Rauc_service.build_module rauc in
  let%lwt curlI = Curl_proxy.init connman in

  let module Deps = struct
    let config = config
    module RaucI = (val raucI)
    module CurlI = (val curlI)
  end in

  Lwt.return (module Deps : ServiceDeps)

(* "legacy" entry point *)
let start ~connman ~(rauc : Rauc.t) ~(update_url : string) =
  let state_s, set_state = Lwt_react.S.create GettingVersionInfo in
  let () = Logs.info ~src:log_src (fun m -> m "update URL: %s" update_url) in

  let service = begin
      let%lwt deps = build_deps ~connman ~rauc ~update_url in
      let module UpdateServiceI = UpdateService(val deps) in
      UpdateServiceI.run ~set_state GettingVersionInfo
  end in

  let () = Logs.info ~src:log_src (fun m -> m "Started") in
  (state_s, service)
