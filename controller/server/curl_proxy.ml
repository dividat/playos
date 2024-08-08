open Lwt

module type CurlProxyInterface = sig
    val request
      :  ?headers:(string * string) list
      -> ?data:string
      -> ?options:string list
      -> Uri.t
      -> Curl.result Lwt.t
end

let get_proxy_uri connman =
  Connman.Manager.get_default_proxy connman
    >|= Option.map (Connman.Service.Proxy.to_uri ~include_userinfo:true)

let build_module (proxy: Uri.t option) =
  let module CurlWrap = struct
    let request = Curl.request ?proxy
  end in
  (module CurlWrap : CurlProxyInterface)

let init connman =
  (* TODO: this could take only `unit` as an argument by just getting
     the connman reference like this:
  let%lwt connman = Connman.Manager.connect () in *)
  let%lwt proxy = get_proxy_uri connman in
  Lwt.return @@ build_module proxy

