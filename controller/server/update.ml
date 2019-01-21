open Lwt
open Sexplib.Std

let log_src = Logs.Src.create "update-mechanism"


(* Version handling *)

(* Compatible with Semver.t but also deriving sexp *)
type semver = int * int * int [@@deriving sexp]

(** Type containing version information *)
type version_info =
  {(* the latest available version *)
    latest : semver

  (* version of currently booted system *)
  ; booted : semver

  (* version of inactive system *)
  ; inactive : semver
  }
[@@deriving sexp]


(** Helper to parse semver from string or fail *)
let semver_of_string string =
  match Semver.of_string string with
  | None ->
    failwith
      (Format.sprintf "could not parse version (version string: %s)" string)
  | Some version ->
    version

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


(* Update mechanism process *)


let start ~(rauc:Rauc.t) ~(update_url:string) =
  let%lwt () = Logs_lwt.info ~src:log_src (fun m -> m "update mechanism starting up") in

  let%lwt () =
    match%lwt get_version_info update_url rauc with
    | Ok version_info ->
      version_info
      |> sexp_of_version_info
      |> Sexplib.Sexp.to_string_hum
      |> Lwt_io.printl
    | Error exn ->
      Logs_lwt.err ~src:log_src (fun m -> m "failed to get version information (%s)"
                                    (Printexc.to_string exn))

  in

  Lwt_unix.sleep 1.0

