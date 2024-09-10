open Lwt

module type S = sig
    (* download bundle version and return the file system path *)
    val download : string -> string Lwt.t

    (** Get latest version available *)
    val get_latest_version : unit -> string Lwt.t
end

module type UpdateClientDeps = sig
    val base_url: Uri.t
    val download_dir: string
    val get_proxy: unit -> Uri.t option Lwt.t
end

let make_deps ?(download_dir="/tmp") get_proxy base_url : (module UpdateClientDeps) = (module struct
    let base_url = base_url
    let get_proxy = get_proxy
    let download_dir = download_dir
end)

let bundle_name = Config.System.bundle_name

let bundle_file_name version =
  Format.sprintf "%s-%s.raucb" bundle_name version

let ensure_trailing_slash uri =
    let u = Uri.to_string uri in
    if (String.ends_with ~suffix:"/" @@ u) then
        u
    else
        (u ^ "/")

module UpdateClient (DepsI: UpdateClientDeps) = struct
    let get_proxy = DepsI.get_proxy
    let download_dir = DepsI.download_dir
    let base_url = ensure_trailing_slash DepsI.base_url

    let download_url version_string =
      Format.sprintf "%s%s/%s" base_url version_string (bundle_file_name version_string)
      |>
      Uri.of_string

    (** Get latest version available *)
    let get_latest_version () =
      let%lwt proxy = get_proxy () in
      match%lwt Curl.request ?proxy (Uri.of_string (base_url ^ "latest")) with
      | RequestSuccess (_, body) ->
          return body
      | RequestFailure error ->
          Lwt.fail_with (Printf.sprintf "could not get latest version (%s)" (Curl.pretty_print_error error))

    (** download RAUC bundle *)
    let download version =
      let url = download_url version in
      let bundle_path = Format.sprintf
        "%s/%s" download_dir (bundle_file_name version)
      in
      let options =
        [ "--continue-at"; "-" (* resume download *)
        ; "--limit-rate"; "10M"
        ; "--output"; bundle_path
        ]
      in
      let%lwt proxy = get_proxy () in
      match%lwt Curl.request ?proxy ~options url with
      | RequestSuccess _ ->
          return bundle_path
      | RequestFailure error ->
          Lwt.fail_with (Printf.sprintf "could not download RAUC bundle (%s)" (Curl.pretty_print_error error))
end

module Make (DepsI : UpdateClientDeps) = UpdateClient (DepsI)

let get_proxy_uri connman =
  Connman.Manager.get_default_proxy connman
    >|= Option.map (Connman.Service.Proxy.to_uri ~include_userinfo:true)

let build_module connman =
  (* TODO: this could take only `unit` as an argument by just getting
     the connman reference like this:
  let%lwt connman = Connman.Manager.connect () in *)
  let get_proxy () = get_proxy_uri connman in
  let depsI = make_deps get_proxy (Uri.of_string Config.System.update_url) in
  Lwt.return @@ (module UpdateClient (val depsI : UpdateClientDeps) : S)
