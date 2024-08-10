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

let bundle_name = Config.System.bundle_name

let bundle_file_name version =
  Format.sprintf "%s-%s.raucb" bundle_name version

module UpdateClient (CurlI : CurlProxyInterface) = struct
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
      match%lwt CurlI.request (Uri.of_string (base_url ^ "latest")) with
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
