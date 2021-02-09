open Lwt

let log_src = Logs.Src.create "zerotier"

let base_url =
  Uri.make
    ~scheme:"http"
    ~host:"localhost"
    ~port:9993
    ()

let get_authtoken () =
  Util.read_from_file
    log_src
    "/var/lib/zerotier-one/authtoken.secret"

type status = {
  address: string
}

let get_status () =
  (
    let open Cohttp in
    let open Cohttp_lwt_unix in
    let%lwt authtoken = get_authtoken () in
    let%lwt response,body =
      Client.get
        ~headers:(Header.of_list ["X-ZT1-Auth", authtoken])
        (Uri.with_path base_url "status")
    in
    let%lwt address =
      Ezjsonm.(
        Cohttp_lwt.Body.to_string body
        >|= from_string
        >|= get_dict
        >|= List.assoc "address"
        >|= get_string
      )
    in
    {address}
    |> return
  )
  |> Lwt_result.catch

