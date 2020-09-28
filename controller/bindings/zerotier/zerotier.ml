open Lwt

let base_url =
  Uri.make
    ~scheme:"http"
    ~host:"localhost"
    ~port:9993
    ()

let get_authtoken () =
  let%lwt ic =
    Lwt_io.(open_file ~mode:Lwt_io.Input)
      "/var/lib/zerotier-one/authtoken.secret"
  in
  let%lwt authtoken = Lwt_io.read ic in
  let%lwt () = Lwt_io.close ic in
  authtoken
  |> String.trim
  |> return

type status = {
  address: string
}

let get_status ~proxy =
  (
    let open Cohttp in
    let open Cohttp_lwt_unix in
    let%lwt authtoken = get_authtoken () in
    let%lwt response,body =
      Client.get
        ?proxy
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
