open Lwt

let log_src = Logs.Src.create "zerotier"

let base_url = Uri.make ~scheme:"http" ~host:"localhost" ~port:9993 ()

let get_authtoken () =
  Util.read_from_file log_src "/var/lib/zerotier-one/authtoken.secret"

type status = { address : string }

let get_status () =
  Lwt_result.catch (fun () ->
      let%lwt authtoken = get_authtoken () in
      match%lwt
        Curl.request
          ~headers:[ ("X-ZT1-Auth", authtoken) ]
          (Uri.with_path base_url "status")
      with
      | RequestSuccess (_, body) ->
          let open Ezjsonm in
          from_string body
          |> get_dict
          |> List.assoc "address"
          |> get_string
          |> fun address -> return { address }
      | RequestFailure error ->
          Lwt.fail_with (Curl.pretty_print_error error)
  )
