open Lwt
open Sexplib.Conv

let log_src = Logs.Src.create "update"

(* Version handling *)

(** Type containing version information *)
type version_info =
  { (* the latest available version *)
    latest : Semver.t (* version of currently booted system *)
  ; booted : Semver.t (* version of inactive system *)
  ; inactive : Semver.t
  }

let sexp_of_version_info v =
  let open Sexplib in
  Sexp.(
    List
      [ List [ Atom "latest"; Atom (Semver.to_string v.latest) ]
      ; List [ Atom "booted"; Atom (Semver.to_string v.booted) ]
      ; List [ Atom "inactive"; Atom (Semver.to_string v.inactive) ]
      ]
  )

type update_error =
  | ErrorGettingVersionInfo of string
  | ErrorDownloading of string
  | ErrorInstalling of string
[@@deriving sexp_of]

type system_status =
  | UpToDate
  | NeedsUpdate
  | RebootRequired
  | OutOfDateVersionSelected
  | ReinstallRequired
  | UpdateError of update_error
[@@deriving sexp_of]

type sleep_duration = float (* seconds *) [@@deriving sexp_of]

(** State of update mechanism *)
type process_state =
  | Sleeping of sleep_duration
  | GettingVersionInfo
  | Downloading of string
  | Installing of string
[@@deriving sexp_of]

type state =
  { version_info : version_info option
  ; system_status : system_status
  ; process_state : process_state
  }
[@@deriving sexp_of]

type config =
  { http_error_backoff_duration : sleep_duration
  ; install_error_backoff_duration : sleep_duration
  ; check_for_updates_interval : sleep_duration
  }

module type ServiceDeps = sig
  module ClientI : Update_client.S

  module RaucI : Rauc_service.S

  val config : config
end

module type UpdateService = sig
  val run : (state -> unit) -> unit Lwt.t

  val run_step : state -> state Lwt.t
end

let evaluate_version_info current_primary booted_slot version_info =
  (* Compare latest available version to version booted. *)
  let up_to_date_with_latest v = Semver.compare v version_info.latest >= 0 in
  let booted_up_to_date = up_to_date_with_latest version_info.booted in
  let inactive_up_to_date = up_to_date_with_latest version_info.inactive in
  if booted_up_to_date && inactive_up_to_date then
    (* Should not happen during the automatic update process (one partition must
       always be older than latest upstream), but can happen if e.g. a newer
       version is manually installed into one of the slots. *)
    UpToDate
  else if booted_up_to_date || inactive_up_to_date then
    match current_primary with
    | Some primary_slot ->
        if booted_up_to_date then
          (* Don't care if inactive can be updated. I.e. Only update the inactive
             partition once the booted partition is outdated. This results in
             always two versions being available on the machine. *)
          UpToDate
        else if booted_slot = primary_slot then
          (* Inactive is up to date while booted is out of date, but booted was
             specifically selected for boot *)
          OutOfDateVersionSelected
        else
          (* If booted is not up to date but inactive is both up to date and
             primary, we should reboot into the primary *)
          RebootRequired
    | None ->
        (* All systems bad; suggest reinstallation *)
        ReinstallRequired
  else NeedsUpdate

(** Helper to parse semver from string or fail *)
let semver_of_string string =
  let trimmed_string = String.trim string in
  match Semver.of_string trimmed_string with
  | None ->
      failwith
        (Format.sprintf "could not parse version (version string: %s)" string)
  | Some version ->
      version

let initial_state =
  { version_info = None
  ; system_status = UpToDate
  ; (* start with assuming a good state *)
    process_state = GettingVersionInfo
  }

module Make (Deps : ServiceDeps) : UpdateService = struct
  open Deps

  (** Get version information *)
  let get_version_info () =
    let%lwt latest = ClientI.get_latest_version () >|= semver_of_string in
    let%lwt rauc_status = RaucI.get_status () in
    let system_a_version = rauc_status.a.version |> semver_of_string in
    let system_b_version = rauc_status.b.version |> semver_of_string in
    match%lwt RaucI.get_booted_slot () with
    | SystemA ->
        { latest; booted = system_a_version; inactive = system_b_version }
        |> return
    | SystemB ->
        { latest; booted = system_b_version; inactive = system_a_version }
        |> return

  (* Update mechanism process *)

  (** Perform a single state transition from given state

        Note: the action performed depends _only_ on the input
        state.process_state.
     *)
  let run_step (state : state) : state Lwt.t =
    match state.process_state with
    | GettingVersionInfo -> (
        (* get version information and decide what to do *)
        let%lwt resp =
          Lwt_result.catch (fun () ->
              let%lwt slot_primary = RaucI.get_primary () in
              let%lwt slot_booted = RaucI.get_booted_slot () in
              let%lwt vsn_resp = get_version_info () in
              return (slot_primary, slot_booted, vsn_resp)
          )
        in
        match resp with
        | Ok (slot_p, slot_b, version_info) ->
            let system_status =
              evaluate_version_info slot_p slot_b version_info
            in
            let next_proc_state =
              match system_status with
              | NeedsUpdate ->
                  Downloading (Semver.to_string version_info.latest)
              | _ ->
                  Sleeping config.check_for_updates_interval
            in
            return
              { process_state = next_proc_state
              ; version_info = Some version_info
              ; system_status
              }
        | Error exn ->
            let exn_str = Printexc.to_string exn in
            let%lwt () =
              Logs_lwt.err ~src:log_src (fun m ->
                  m "failed to get version information: %s" exn_str
              )
            in
            return
              { process_state = Sleeping config.http_error_backoff_duration
              ; (* unsetting version_info to indicate we are unclear about
                   current system state *)
                version_info = None
              ; system_status = UpdateError (ErrorGettingVersionInfo exn_str)
              }
      )
    | Sleeping duration ->
        let%lwt () = Lwt_unix.sleep duration in
        return { state with process_state = GettingVersionInfo }
    | Downloading version -> (
        (* download latest version *)
        match%lwt Lwt_result.catch (fun () -> ClientI.download version) with
        | Ok bundle_path ->
            return { state with process_state = Installing bundle_path }
        | Error exn ->
            let exn_str = Printexc.to_string exn in
            let%lwt () =
              Logs_lwt.err ~src:log_src (fun m ->
                  m "failed to download RAUC bundle: %s" exn_str
              )
            in
            return
              { state with
                process_state = Sleeping config.http_error_backoff_duration
              ; system_status = UpdateError (ErrorDownloading exn_str)
              }
      )
    | Installing bundle_path -> (
        (* install bundle via RAUC *)
        match%lwt Lwt_result.catch (fun () -> RaucI.install bundle_path) with
        | Ok () ->
            let%lwt () =
              Logs_lwt.info (fun m ->
                  m "succesfully installed update (%s)" bundle_path
              )
            in
            return
              { state with
                (* unsetting version_info, because it is now stale *)
                version_info = None
              ; (* going back to GettingVersionInfo to update version_info *)
                process_state = GettingVersionInfo
              }
        | Error exn ->
            let () = try Sys.remove bundle_path with _ -> () in
            let exn_str = Printexc.to_string exn in
            let%lwt () =
              Logs_lwt.err ~src:log_src (fun m ->
                  m "failed to install RAUC bundle: %s" exn_str
              )
            in
            return
              { state with
                process_state = Sleeping config.install_error_backoff_duration
              ; system_status = UpdateError (ErrorInstalling exn_str)
              }
      )

  let rec run_rec set_state state =
    let%lwt next_state = run_step state in
    set_state next_state ;
    run_rec set_state next_state

  let run set_state = run_rec set_state initial_state
end

let default_config : config =
  { http_error_backoff_duration = 30.0
  ; install_error_backoff_duration = 5. *. 60.
  ; check_for_updates_interval = 1. *. 60. *. 60.
  }

let build_deps ~connman ~(rauc : Rauc.t) : (module ServiceDeps) Lwt.t =
  let config = default_config in
  let raucI = Rauc_service.build_module rauc in
  let clientI = Update_client.build_module connman in
  let module Deps = struct
    let config = config

    module RaucI = (val raucI)

    module ClientI = (val clientI)
  end in
  Lwt.return (module Deps : ServiceDeps)

let start ~connman ~(rauc : Rauc.t) =
  let state_s, set_state = Lwt_react.S.create initial_state in
  let () =
    Logs.info ~src:log_src (fun m -> m "update URL: %s" Config.System.update_url)
  in
  let service =
    let%lwt deps = build_deps ~connman ~rauc in
    let module UpdateServiceI = Make ((val deps)) in
    UpdateServiceI.run set_state
  in
  let () = Logs.info ~src:log_src (fun m -> m "Started") in
  (state_s, service)
