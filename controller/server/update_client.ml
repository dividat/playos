open Lwt

(* unparsed semver version *)
type version = string
(* local filesystem path *)
type bundle_path = string

module type UpdateClientIntf = sig
    (* download bundle from specified url and save it as `version` *)
    val download : Uri.t -> version -> bundle_path Lwt.t

    (* URL from which the specified version would be downloaded *)
    val download_url : version -> Uri.t

    (** Get latest version available *)
    val get_latest_version : unit -> version Lwt.t
end

module type ProxyProvider = sig
    val proxy: Uri.t option
end

let proxy_provider proxy : (module ProxyProvider) = (module struct
    let proxy = proxy
end)

let bundle_name = Config.System.bundle_name

let bundle_file_name version =
  Format.sprintf "%s-%s.raucb" bundle_name version

(* NOTE/TODO: potential simplification:

    UpdateClient does not care and need to know about the possibility of a
    proxy, since we are interfacing with curl via bindings that spawn a
    subprocess it would be sufficient to set the appropriate `http_proxy` env
    variable system-wide (at run time) and let curl figure out whether it needs
    to use a proxy or not itself.

    This would allow getting rid of this ProxyProvider and simplify a lot of the
    code. *)
module UpdateClient (ProxyI: ProxyProvider) = struct
    let proxy = ProxyI.proxy

    let base_url = Config.System.update_url

    (* TODO: FIX: this will produce an invalid URL if ~update_url is missing a
       trailing slash *)
    (* TODO: Should probably be moved to config too *)
    let download_url version_string =
      Format.sprintf "%s%s/%s" base_url version_string (bundle_file_name version_string)
      |>
      Uri.of_string

    (** Get latest version available *)
    let get_latest_version () =
      match%lwt Curl.request ?proxy (Uri.of_string (base_url ^ "latest")) with
      | RequestSuccess (_, body) ->
          return body
      | RequestFailure error ->
          Lwt.fail_with (Printf.sprintf "could not get latest version (%s)" (Curl.pretty_print_error error))

    (** download RAUC bundle *)
    let download url version =
      let bundle_path = Format.sprintf "/tmp/%s" (bundle_file_name version) in
      let options =
        [ "--continue-at"; "-" (* resume download *)
        ; "--limit-rate"; "10M"
        ; "--output"; bundle_path
        ]
      in
      match%lwt Curl.request ?proxy ~options url with
      | RequestSuccess _ ->
          return bundle_path
      | RequestFailure error ->
          Lwt.fail_with (Printf.sprintf "could not download RAUC bundle (%s)" (Curl.pretty_print_error error))
end

module Make (ProxyI : ProxyProvider) = UpdateClient (ProxyI)

let get_proxy_uri connman =
  Connman.Manager.get_default_proxy connman
    >|= Option.map (Connman.Service.Proxy.to_uri ~include_userinfo:true)

let init connman =
  (* TODO: this could take only `unit` as an argument by just getting
     the connman reference like this:
  let%lwt connman = Connman.Manager.connect () in *)
  let%lwt proxy = get_proxy_uri connman in
  let proxyI = proxy_provider proxy in
  Lwt.return @@ (module UpdateClient (val proxyI : ProxyProvider) : UpdateClientIntf)
