open Lwt

(* tiny wrapper around Curl bindings with implicit
   proxy resolution *)
module type CurlProxyInterface = sig
    val request
      :  ?headers:(string * string) list
      -> ?data:string
      -> ?options:string list
      -> Uri.t
      -> Curl.result Lwt.t
end

type version = string
type bundle_path = string
type version_pair = (Semver.t [@sexp.opaque]) * string

module type UpdateClientIntf = sig
    val download : Uri.t -> version -> bundle_path Lwt.t

    (** Get latest version available at [url] *)
    val get_latest_version : unit -> version_pair Lwt.t

end

(* TODO: move to semver helpers or similar *)
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

    
let bundle_name =
  "@PLAYOS_BUNDLE_NAME@"

let bundle_file_name version =
  Format.sprintf "%s-%s.raucb" bundle_name version

(* TODO: FIX: this will produce an invalid URL if ~update_url is missing a
   trailing slash *)
(* TODO: Should probably be moved to config too *)
let latest_download_url ~update_url version_string =
  Format.sprintf "%s%s/%s" update_url version_string (bundle_file_name version_string)

module UpdateClient (CurlI : CurlProxyInterface) = struct
    let url = "UPDATE_URL_TO_SPECIFY"

    (** Get latest version available at [url] *)
    let get_latest_version () =
      match%lwt CurlI.request (Uri.of_string (url ^ "latest")) with
      | RequestSuccess (_, body) ->
          return (semver_of_string body)
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
      match%lwt CurlI.request ~options url with
      | RequestSuccess _ ->
          return bundle_path
      | RequestFailure error ->
          Lwt.fail_with (Printf.sprintf "could not download RAUC bundle (%s)" (Curl.pretty_print_error error))
end

let get_proxy_uri connman =
  Connman.Manager.get_default_proxy connman
    >|= Option.map (Connman.Service.Proxy.to_uri ~include_userinfo:true)

let build_module_curl (proxy: Uri.t option) =
  let module CurlWrap = struct
    let request = Curl.request ?proxy
  end in
  (module CurlWrap : CurlProxyInterface)

let build_module (module CurlWrap: CurlProxyInterface) =
  (module UpdateClient (CurlWrap) : UpdateClientIntf )

let init connman =
  (* TODO: this could take only `unit` as an argument by just getting
     the connman reference like this:
  let%lwt connman = Connman.Manager.connect () in *)
  let%lwt proxy = get_proxy_uri connman in
  let curlI = build_module_curl proxy in
  Lwt.return @@ (module UpdateClient (val curlI : CurlProxyInterface) :
      UpdateClientIntf )

