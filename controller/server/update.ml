open Lwt
open Sexplib.Std

let log_src = Logs.Src.create "update-mechanism"


(* Version handling *)

(* Compatible with Semver.t but also deriving sexp *)
type semver = int * int * int [@@deriving sexp]

(** Type containing version information *)
type version_info =
  {(* the latest available version *)
    latest : semver * string

  (* version of currently booted system *)
  ; booted : semver * string

  (* version of inactive system *)
  ; inactive : semver * string
  }
[@@deriving sexp]


(** Helper to parse semver from string or fail *)
let semver_of_string string =
  match Semver.of_string string with
  | None ->
    failwith
      (Format.sprintf "could not parse version (version string: %s)" string)
  | Some version ->
    version, string

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


(** download RAUC bundle *)
let download ~update_url ~version =
  let bundle = Format.sprintf "playos-%s.raucb" version in
  (* TODO: save bundle to a more sensible location *)
  let bundle_path = Format.sprintf "/tmp/%s" bundle in
  let url = Format.sprintf "%s/%s/%s" update_url version bundle in
  let command =
    "", [| "curl"
         ; url
         (* resume download *)
         ; "-C"; "-"
         (* limit download speed *)
         ; "--limit-rate"; "2M"
         ; "-o"; bundle_path |]
  in
  match%lwt Lwt_process.exec
              ~stdout:`Dev_null
              ~stderr:`Dev_null
              command with
  | Unix.WEXITED 0 ->
    return bundle_path
  | _ ->
    Lwt.fail_with "could not download RAUC bundle"


(* Update mechanism process *)
type state =
  | GettingVersionInfo
  | ErrorGettingVersionInfo of string
  | Uptodate of version_info
  | Downloading of version_info
  | ErrorDownloading of string
  | Installing of string
[@@deriving sexp]

(** Finite state machine handling updates *)
let rec run ~update_url ~rauc ~set_state =
  (* Helper to update state in signal and advance state machine *)
  let set state =
    set_state state; run ~update_url ~rauc ~set_state state
  in
  function
  | GettingVersionInfo ->
    (match%lwt get_version_info update_url rauc with
     | Ok version_info ->
       let%lwt () =
         Logs_lwt.debug ~src:log_src
           (fun m -> m "version information: %s"
               (version_info
                |> sexp_of_version_info
                |> Sexplib.Sexp.to_string_hum))
       in
       let version_compare = Semver.compare
           (fst version_info.latest)
           (fst version_info.inactive) in
       if version_compare == 0 then
         (*TODO: check if booted < inactive and then set state to RebootRequired *)
         Uptodate version_info
         |> set
       else if version_compare > 0 then
         Downloading version_info
         |> set
       else
         ErrorGettingVersionInfo "latest available version is less than installed version"
         |> set

     | Error exn ->
       let%lwt () =
         Logs_lwt.err ~src:log_src
           (fun m -> m "failed to get version information (%s)"
               (Printexc.to_string exn))
       in
       ErrorGettingVersionInfo (Printexc.to_string exn)
       |> set
    )

  | ErrorGettingVersionInfo _ ->
    (* Wait for 30 seconds and retry *)
    let%lwt () = Lwt_unix.sleep 30.0 in
    set GettingVersionInfo

  | Uptodate version_info ->
    (* Wait for 6 of hours and recheck *)
    let%lwt () = Lwt_unix.sleep (6. *. 60. *. 60.) in
    set GettingVersionInfo

  | Downloading version_info ->
    let download_version = snd version_info.latest in
    (match%lwt download update_url download_version |> Lwt_result.catch with
     | Ok bundle_path ->
       Installing bundle_path
       |> set
     | Error exn ->
       ErrorDownloading (Printexc.to_string exn)
       |> set
    )

  | ErrorDownloading _ ->
    (* Wait for 30 seconds and retry *)
    let%lwt () = Lwt_unix.sleep 30.0 in
    set GettingVersionInfo

  | _ ->
    return_unit

let start ~(rauc:Rauc.t) ~(update_url:string) =
  let state_s, set_state = Lwt_react.S.create GettingVersionInfo in
  let () =
    Lwt_react.S.map (fun state ->
        Logs.debug (fun m -> m "update state: %s"
                       (state
                        |> sexp_of_state
                        |> Sexplib.Sexp.to_string_hum)))
      state_s
    |> Lwt_react.S.keep
  in

  state_s, run ~update_url ~rauc ~set_state GettingVersionInfo

