open Lwt

let get () =
  let command =
    ( "/run/current-system/sw/bin/connman-manual-proxy"
    , [| "connman-manual-proxy" |]
    )
  in
  let%lwt proxy_str = Lwt_process.pread command >|= String.trim in
  if String.trim proxy_str = "" then
    return None
  else
    return (Proxy.validate proxy_str)
