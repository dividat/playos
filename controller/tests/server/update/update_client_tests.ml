(**
   Tests Update_client using a mock HTTP server. Since Update_client is
   invoking Curl via a subprocess, this is more of an integration test than a
   pure unit test.

   Most tests are run twice: once with Update_client configured without a proxy
   and then again with a proxy. Note: there is no actual HTTP proxy used,
   the proxy scenario is realized by setting an invalid dist server URL and
   using the mock server as a proxy.
*)
open Update_client

open Update_client_mock_server

let setup_log () =
  Fmt_tty.setup_std_outputs () ;
  Logs.set_level @@ Some Logs.Debug ;
  Logs.set_reporter (Logs_fmt.reporter ()) ;
  ()

type proxy_param =
  | NoProxy
  | UseMockServer
  | Custom of string

(* returns (proxy, server_url) pair *)
let process_proxy_spec spec server_url =
  match spec with
  | NoProxy ->
      (None, server_url)
  | UseMockServer ->
      (* pretend mock server is a proxy, i.e. use an invalid base_url,
         and the actual server_url for the proxy *)
      ( server_url |> Option.some
      , (* Note: DO NOT use https here, because curl will attempt
           to CONNECT and then this whole setup doesn't work *)
        Uri.of_string "http://some-invalid-url.local/"
      )
  | Custom p ->
      (p |> Uri.of_string |> Option.some, server_url)

let rec wait_for_mock_server ?(timeout = 0.2) ?(remaining_tries = 3) url =
  let status_endpoint = Uri.of_string (url ^ "ready") in
  let%lwt rez = Curl.request status_endpoint in
  match rez with
  | Curl.RequestSuccess _ ->
      Lwt.return ()
  | Curl.RequestFailure err ->
      let err_msg = Curl.pretty_print_error err in
      print_endline ("MockServer not up, err was: " ^ err_msg) ;
      if remaining_tries > 0 then
        let%lwt () = Lwt_unix.sleep timeout in
        wait_for_mock_server
          ~timeout:(timeout *. 2.0) (* exponential backoff *)
          ~remaining_tries:(remaining_tries - 1) url
      else
        let err_msg =
          "HTTP mock server did not become ready, last error: "
          ^ Curl.pretty_print_error err
        in
        Lwt.fail (Failure err_msg)

let run_test_case ?(proxy = NoProxy) switch f =
  let server = mock_server () in
  let server_url, server_task = server#run () in
  let%lwt () = wait_for_mock_server server_url in
  Lwt_switch.add_hook (Some switch) (fun () ->
      Lwt.return @@ Lwt.cancel server_task
  ) ;
  let proxy_url, base_url =
    process_proxy_spec proxy (Uri.of_string server_url)
  in
  let get_proxy () = Lwt.return proxy_url in
  let temp_dir =
    Format.sprintf "%s/upd-client-test-%d"
      (Filename.get_temp_dir_name ())
      (Unix.gettimeofday () |> fun x -> x *. 1000.0 |> int_of_float)
  in
  let () = Sys.mkdir temp_dir 0o777 in
  let module DepsI =
    ( val Update_client.make_deps ~download_dir_override:temp_dir get_proxy
            base_url
      )
  in
  let module UpdateC = Update_client.Make (DepsI) in
  f server (module UpdateC : S)

let test_get_version_ok server (module Client : S) =
  let expected_version = "1.0.0" in
  let () = server#set_latest_version expected_version in
  let%lwt vsn = Client.get_latest_version () in
  Lwt.return
  @@ Alcotest.(check string) "Latest version is fetched" expected_version vsn

let read_file file = In_channel.with_open_bin file In_channel.input_all

let test_download_bundle_ok server (module Client : S) =
  let version = "1.0.0" in
  let bundle = "BUNDLE_CONTENTS" in
  let () = server#add_bundle version bundle in
  let%lwt bundle_path = Client.download version in
  Alcotest.(check bool)
    "Bundle file is downloaded and saved"
    (Sys.file_exists bundle_path)
    true ;
  Alcotest.(check string)
    "Bundle contents are correct" (read_file bundle_path) bundle ;
  Lwt.return ()

(* NOTE: This test checks that the client resumes the download
   from where it finished, but also it is an example of why naive
   resuming might not be a great idea.*)
let test_resume_bundle_download server (module Client : S) =
  let version = "1.0.0" in
  let bundle_contents = "BUNDLE_CONTENTS: 123" in
  let () = server#add_bundle version bundle_contents in
  let%lwt bundle_path = Client.download version in
  Alcotest.(check string)
    "Bundle contents are only partial" (read_file bundle_path) bundle_contents ;
  (* NOTE that bundle_contents is not a prefix of bundle_contents_extra !
     This is on purpose: to check that download client does not simply
     overwrite the downloaded file, otherwise we would not be testing
     whether it really resumes the downloaded. It also illustrates
     that curl / HTTP range request do not involve any integrity checking,
     bytes are just being appended to the end.
  *)
  let bundle_contents_extra = "BUNDLE_CONTENTS: 111999" in
  let () = server#add_bundle version bundle_contents_extra in
  let%lwt bundle_path = Client.download version in
  Alcotest.(check string)
    "Bundle contents are resumed, not overwritten" (read_file bundle_path)
    (* NOTE: this is not the same as [bundle_contents_extra], it is only
       the last bytes of it beyond the length of [bundle_contents] *)
    "BUNDLE_CONTENTS: 123999" ;
  Lwt.return ()

(* invalid proxy URL is set in the `run_test_case` function, see below *)
let test_invalid_proxy_fail _ (module Client : S) =
  Lwt.try_bind Client.get_latest_version
    (fun _ ->
      Alcotest.fail "Get version was supposed to fail due to invalid proxy"
    )
    (function
      | Failure exn ->
          Alcotest.(check bool)
            "Curl raised an exception about invalid proxy"
            (Str.string_match (Str.regexp ".*Could not resolve proxy.*") exn 0)
            true ;
          Lwt.return ()
      | other_exn ->
          Alcotest.fail
          @@ "Got unexpected exception: "
          ^ Printexc.to_string other_exn
      )

let () =
  let () = setup_log () in
  (* All tests cases are run with proxy setup and without to verify it works
     always *)
  let test_cases =
    [ ("Get latest version", test_get_version_ok)
    ; ("Download bundle", test_download_bundle_ok)
    ; ("Resume download works", test_resume_bundle_download)
    ]
  in
  (* An extra case to check that proxy settings are honored in general *)
  let invalid_proxy_case =
    Alcotest_lwt.test_case "Invalid proxy specified" `Quick (fun switch () ->
        run_test_case ~proxy:(Custom "http://not-a-proxy.internal") switch
          test_invalid_proxy_fail
    )
  in
  Lwt_main.run
  @@ Alcotest_lwt.run "Basic tests"
       [ ( "without-proxy"
         , List.map
             (fun (name, test_f) ->
               Alcotest_lwt.test_case name `Quick (fun switch () ->
                   run_test_case switch test_f
               )
             )
             test_cases
         )
       ; ( "with-proxy"
         , invalid_proxy_case
           :: List.map
                (fun (name, test_f) ->
                  Alcotest_lwt.test_case name `Quick (fun switch () ->
                      run_test_case ~proxy:UseMockServer switch test_f
                  )
                )
                test_cases
         )
       ]
