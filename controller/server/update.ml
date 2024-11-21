open Lwt
open Sexplib.Conv

let log_src = Logs.Src.create "update"

(* Version handling *)

(** Type containing version information *)
type version_info =
  {(* the latest available version *)
    latest : Semver.t

  (* version of currently booted system *)
  ; booted : Semver.t

  (* version of inactive system *)
  ; inactive : Semver.t
  }

let sexp_of_version_info v =
    let open Sexplib in
    Sexp.(List [
        List [Atom "latest";   Atom (Semver.to_string v.latest)];
        List [Atom "booted";   Atom (Semver.to_string v.booted)];
        List [Atom "inactive"; Atom (Semver.to_string v.inactive)];
    ])



type state =
  | GettingVersionInfo
  | ErrorGettingVersionInfo of string
  | UpToDate of version_info
  | Downloading of string
  | ErrorDownloading of string
  | Installing of string
  | ErrorInstalling of string
  (* inactive system has been updated and reboot is required to boot into updated system *)
  | RebootRequired
  (* inactive system is up to date, but current system was selected for boot *)
  | OutOfDateVersionSelected
  (* there are no known-good systems and a reinstall is recommended *)
  | ReinstallRequired
[@@deriving sexp_of]

type sleep_duration = float (* seconds *)

type config = {
    error_backoff_duration: sleep_duration;
    check_for_updates_interval: sleep_duration;
}

module type ServiceDeps = sig
    module ClientI: Update_client.S
    module RaucI: Rauc_service.S
    val config : config
end

module type UpdateService = sig
  val run : set_state:(state -> unit) -> state -> unit Lwt.t

  val run_step : state -> state Lwt.t
end

let evaluate_version_info current_primary booted_slot version_info =
  (* Compare latest available version to version booted. *)
  let up_to_date_with_latest v = Semver.compare v version_info.latest >=0 in
  let booted_up_to_date = up_to_date_with_latest version_info.booted in
  let inactive_up_to_date = up_to_date_with_latest version_info.inactive in

  if booted_up_to_date && inactive_up_to_date then
  (* Should not happen during the automatic update process (one partition must
     always be older than latest upstream), but can happen if e.g. a newer
     version is manually installed into one of the slots. *)
    UpToDate version_info
  else if booted_up_to_date || inactive_up_to_date then
    match current_primary with
    | Some primary_slot ->
      if booted_up_to_date then
        (* Don't care if inactive can be updated. I.e. Only update the inactive
           partition once the booted partition is outdated. This results in
           always two versions being available on the machine. *)
        UpToDate version_info
      else
        if booted_slot = primary_slot then
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

  else
    (* Both systems are out of date -> update the inactive system *)
    Downloading (Semver.to_string version_info.latest)


(** Helper to parse semver from string or fail *)
let semver_of_string string =
  let trimmed_string = String.trim string
  in
  match Semver.of_string trimmed_string with
  | None ->
    failwith
      (Format.sprintf "could not parse version (version string: %s)" string)
  | Some version ->
    version

module Make(Deps : ServiceDeps) : UpdateService = struct
    open Deps

    let sleep_error_backoff () =
        Lwt_unix.sleep config.error_backoff_duration

    let sleep_update_check () =
        Lwt_unix.sleep config.check_for_updates_interval

    (** Get version information *)
    let get_version_info () =
          let%lwt latest = ClientI.get_latest_version () >|= semver_of_string in
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

(* Update mechanism process *)
    (** perform a single state transition from given state *)
    let run_step (state:state) : state Lwt.t =
       let set = Lwt.return in
       match (state) with
      | GettingVersionInfo ->
        (* get version information and decide what to do *)
        let%lwt resp = Lwt_result.catch (fun () ->
            let%lwt slot_primary = RaucI.get_primary () in
            let%lwt slot_booted = RaucI.get_booted_slot () in
            let%lwt vsn_resp = get_version_info () in
            return (slot_primary, slot_booted, vsn_resp)
        ) in
        (match resp with
            | Ok (slot_p, slot_b, version_info) ->
                evaluate_version_info slot_p slot_b version_info
            | Error e ->
                ErrorGettingVersionInfo (Printexc.to_string e)
        ) |> set

      | ErrorGettingVersionInfo msg ->
        (* handle error while getting version information *)
        let%lwt () =
          Logs_lwt.err ~src:log_src
            (fun m -> m "failed to get version information: %s" msg)
        in
        (* sleep and retry *)
        let%lwt () = sleep_error_backoff () in
        set GettingVersionInfo

      | Downloading version ->
        (* download latest version *)
        (match%lwt Lwt_result.catch (fun () -> ClientI.download version) with
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
        let%lwt () = sleep_error_backoff () in
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
        let%lwt () = sleep_error_backoff () in
        set GettingVersionInfo

      | UpToDate _
      | RebootRequired
      | OutOfDateVersionSelected
      | ReinstallRequired ->
        (* sleep and recheck for new updates *)
        let%lwt () = sleep_update_check () in
        set GettingVersionInfo

    (** Finite state machine handling updates *)
    let rec run ~set_state state =
      let%lwt next_state = run_step state in
        set_state next_state;
        run ~set_state next_state
end

let default_config : config = {
    error_backoff_duration = 30.0;
    check_for_updates_interval = (1. *. 60. *. 60.)
}

let build_deps ~connman ~(rauc : Rauc.t) :
    (module ServiceDeps) Lwt.t =

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
  let initial_state = GettingVersionInfo in
  let state_s, set_state = Lwt_react.S.create initial_state in
  let () = Logs.info ~src:log_src
    (fun m -> m "update URL: %s" Config.System.update_url) in

  let service = begin
      let%lwt deps = build_deps ~connman ~rauc in
      let module UpdateServiceI = Make(val deps) in
      UpdateServiceI.run ~set_state initial_state
  end in

  let () = Logs.info ~src:log_src (fun m -> m "Started") in
  (state_s, service)
