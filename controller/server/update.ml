open Lwt
open Sexplib.Std
open Sexplib.Conv

let log_src = Logs.Src.create "update"


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

(** Get latest version available at [url] *)
let get_latest_version url =
  let open Cohttp in
  let open Cohttp_lwt_unix in
  let%lwt response,body = try
      Client.get (Uri.of_string (url ^ "latest"))
    with
    | exn -> Lwt.fail exn
  in
  let status = response |> Response.status  in
  let%lwt version_string =
    match status |> Code.code_of_status |> Code.is_success with
    | true -> body |> Cohttp_lwt.Body.to_string
    | false -> Lwt.fail_with (status|> Code.string_of_status)
  in
  version_string
  |> semver_of_string
  |> return

(** Get version information *)
let get_version_info url rauc =
  (
    let%lwt latest = get_latest_version url in
    let%lwt rauc_status = Rauc.get_status rauc in

    let system_a_version = rauc_status.a.version |> semver_of_string in
    let system_b_version = rauc_status.b.version |> semver_of_string in

    match%lwt Rauc.get_booted_slot rauc with
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
  ) |> Lwt_result.catch

let latest_download_url ~update_url version_string =
  let bundle = Format.sprintf "playos-%s.raucb" version_string in
  Format.sprintf "%s%s/%s" update_url version_string bundle

(** download RAUC bundle *)
let download ~url ~version =
  let bundle = Format.sprintf "playos-%s.raucb" version in
  let bundle_path = Format.sprintf "/tmp/%s" bundle in
  let command =
    "/run/current-system/sw/bin/curl",
    [| "curl"; url
     (* resume download *)
     ; "-C"; "-"
     (* limit download speed *)
     ; "--limit-rate"; "10M"
     ; "-o"; bundle_path |]
  in
  let%lwt () =
    Logs_lwt.debug (fun m -> m "download command: %s" (command |> snd |> Array.to_list |> String.concat " "))
  in
  match%lwt Lwt_process.exec
              ~stdout:`Dev_null
              ~stderr:`Dev_null
              command with
  | Unix.WEXITED 0 ->
    return bundle_path
  | Unix.WEXITED exit_code ->
    Lwt.fail_with
      (Format.sprintf "could not download RAUC bundle (exit code: %d)" exit_code)
  | _ ->
    Lwt.fail_with "could not download RAUC bundle"


(* Update mechanism process *)

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


(** Finite state machine handling updates *)
let rec run ~update_url ~rauc ~set_state =
  (* Helper to update state in signal and advance state machine *)
  let set state =
    set_state state; run ~update_url ~rauc ~set_state state
  in
  function
  | GettingVersionInfo ->
    (* get version information and decide what to do *)
    begin
      match%lwt get_version_info update_url rauc with
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
          match%lwt Rauc.get_primary rauc with
          | Some primary_slot ->
            if booted_up_to_date then
              (* Don't care if inactive can be updated. I.e. Only update the inactive partition once the booted partition is outdated. This results in always two versions being available on the machine. *)
              UpToDate version_info |> set
            else
              let%lwt booted_slot = Rauc.get_booted_slot rauc in
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
          let url = latest_download_url ~update_url latest_version in
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
    (* wait for 30 seconds and retry *)
    let%lwt () = Lwt_unix.sleep 30.0 in
    set GettingVersionInfo

  | Downloading {url; version} ->
    (* download latest version *)
    (match%lwt download url version |> Lwt_result.catch with
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
    (* Wait for 30 seconds and retry *)
    let%lwt () = Lwt_unix.sleep 30.0 in
    set GettingVersionInfo

  | Installing bundle_path ->
    (* install bundle via RAUC *)
    (match%lwt Rauc.install rauc bundle_path |> Lwt_result.catch with
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
    (* Wait for 30 seconds and retry *)
    let%lwt () = Lwt_unix.sleep 30.0 in
    set GettingVersionInfo

  | UpToDate _
  | RebootRequired
  | OutOfDateVersionSelected
  | ReinstallRequired ->
    (* wait for an hour and recheck for new updates *)
    let%lwt () = Lwt_unix.sleep (1. *. 60. *. 60.) in
    set GettingVersionInfo


let start ~(rauc:Rauc.t) ~(update_url:string) =
  let state_s, set_state = Lwt_react.S.create GettingVersionInfo in
  let () = Logs.info ~src:log_src (fun m -> m "update URL: %s" update_url) in
  state_s, run ~update_url ~rauc ~set_state GettingVersionInfo
