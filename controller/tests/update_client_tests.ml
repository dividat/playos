open Opium.Std
open Lwt
open Update_client


(* binds on port 0 and returns (loopback addr, port) pair *)
let get_random_available_port () =
    let protocol_id = 0 in
    let sock = Unix.socket Unix.PF_INET Unix.SOCK_STREAM protocol_id in
    let addr = Unix.ADDR_INET (
        Unix.inet_addr_loopback,
        0
    ) in
    let () = Unix.bind sock addr in
    let Unix.ADDR_INET (real_addr, real_port) = Unix.getsockname sock in
    let () = Unix.close sock in
    (Unix.string_of_inet_addr real_addr, real_port)

type state = {
    latest_version: string;
    available_bundles: (string, string) Hashtbl.t ;
}

let stub_server () = object (self)
    val mutable state = ref {
        latest_version = "0.0.0";
        available_bundles = Hashtbl.create 5
    }

    method add_bundle vsn contents =
        Hashtbl.add !state.available_bundles vsn contents

    method remove_bundle vsn contents =
        Hashtbl.remove !state.available_bundles vsn

    method set_latest_version vsn =
        state := {!state with latest_version = vsn}

    method private get_latest_handler _req =
        let resp = Response.of_string_body
            !state.latest_version
        in
        Lwt.return resp

    method private download_bundle_handler req =
          let vsn = Router.param req "vsn" in
          let bundle = Hashtbl.find_opt !state.available_bundles vsn in
          let resp = match bundle with
              | Some bund -> Response.of_string_body bund
              | None -> Response.of_string_body ~code:`Not_found
                  "Bundle version not found"
          in
          Lwt.return resp

    method run () =
      let (addr, port) = get_random_available_port () in
      let server_url = Format.sprintf "http://%s:%d/" addr port in
      let server = App.empty
      |> App.port port
      |> App.get "/latest" self#get_latest_handler
      |> App.get "/ready" (fun (_) -> return @@ Response.create ())
      |> App.get "/:vsn/:bundle" self#download_bundle_handler
      |> App.start
      in
      (server_url, server)
end




let setup_log () =
  Fmt_tty.setup_std_outputs ();
  Logs.set_level @@ Some Logs.Debug;
  Logs.set_reporter (Logs_fmt.reporter ());
  ()

type proxy_param =
    | NoProxy
    | UseStubServer
    | Custom of string

(* returns (proxy, server_url) pair *)
let process_proxy_spec spec server_url =
    match spec with
        | NoProxy ->
            (None, server_url)
        | UseStubServer ->
            (* pretend stub server is a proxy, i.e. use an invalid base_url,
               and the actual server_url for the proxy *)
            (
                (server_url |> Option.some),
                (* Note: DO NOT use https here, because curl will attempt
                   to CONNECT and then this whole setup doesn't work *)
                (Uri.of_string "http://some-invalid-url.local/")
            )
        | Custom p ->
            (
                (p |> Uri.of_string |> Option.some),
                server_url
            )

let rec wait_for_stub_server ?(timeout = 0.2) ?(remaining_tries = 3) url =
    let status_endpoint = Uri.of_string (url ^ "ready") in
    let%lwt rez = Curl.request status_endpoint in
    match rez with
        | Curl.RequestSuccess _ -> Lwt.return ()
        | Curl.RequestFailure err ->
            let err_msg = (Curl.pretty_print_error err) in
            print_endline ("StubServer not up, err was: " ^ err_msg);
            if (remaining_tries > 0) then
                let%lwt () = Lwt_unix.sleep timeout in
                wait_for_stub_server
                    ~timeout:(timeout *. 2.0)  (* exponential backoff *)
                    ~remaining_tries:(remaining_tries - 1) url
           else
                let err_msg = "HTTP stub server did not become ready, last error: " ^ (Curl.pretty_print_error err) in
                Lwt.fail (Failure err_msg)



let run_test_case ?(proxy = NoProxy) switch f =
    let server = stub_server () in
    let (server_url, server_task) = server#run () in
    let%lwt () = wait_for_stub_server server_url in
    Lwt_switch.add_hook (Some switch)
        (fun () -> Lwt.return @@ Lwt.cancel server_task);
    let (proxy_url, base_url) =
        process_proxy_spec proxy (Uri.of_string server_url) in
    let get_proxy () = Lwt.return proxy_url in
    let module DepsI = (val Update_client.make_deps get_proxy base_url) in
    let module UpdateC = Update_client.Make (DepsI) in
    f server (module UpdateC : S)

let test_get_version_ok server (module Client : S) =
    let expected_version = "1.0.0" in
    let () = server#set_latest_version expected_version in
    let%lwt vsn = Client.get_latest_version () in
    return @@ Alcotest.(check string)
        "Latest version is fetched"
        expected_version
        vsn

let read_file file = In_channel.with_open_bin file In_channel.input_all

let test_download_bundle_ok server (module Client : S) =
    let version = "1.0.0" in
    let bundle = "BUNDLE_CONTENTS" in
    let () = server#add_bundle version bundle in
    let%lwt bundle_path = Client.download version in
    Alcotest.(check bool)
        "Bundle file is downloaded and saved"
        (Sys.file_exists bundle_path)
        true;
    Alcotest.(check string)
        "Bundle contents are correct"
        (read_file bundle_path)
        bundle;
    return ()

(* invalid proxy URL is set in the `run_test_case` function, see below *)
let test_invalid_proxy_fail _ (module Client : S) =
  Lwt.try_bind Client.get_latest_version
    (fun _ ->
      Alcotest.fail "Get version was supposed to fail due to invalid proxy")
    (function
      | Failure exn ->
          Alcotest.(check bool)
            "Curl raised an exception about invalid proxy"
            (Str.string_match (Str.regexp ".*Could not resolve proxy.*") exn 0)
            true;
          Lwt.return ()
      | other_exn ->
          Alcotest.fail @@ "Got unexpected exception: "
          ^ Printexc.to_string other_exn)

let () =
  let () = setup_log () in
  (* All tests cases are run with proxy setup and without to verify it works
     always *)
  let test_cases = [
    ("Get latest version", test_get_version_ok);
    ("Download bundle", test_download_bundle_ok);
  ] in
  (* An extra case to check that proxy settings are honored in general *)
  let invalid_proxy_case = Alcotest_lwt.test_case
    "Invalid proxy specified" `Quick
    (fun switch () ->
        run_test_case ~proxy:(Custom "http://not-a-proxy.internal") switch
            test_invalid_proxy_fail)
  in
  Lwt_main.run
  @@ Alcotest_lwt.run "Basic tests"
       [
         ( "without-proxy",
             List.map (fun (name, test_f) ->
                 Alcotest_lwt.test_case name `Quick
                    (fun switch () -> run_test_case switch test_f))
                 test_cases
         );
         ( "with-proxy",
             invalid_proxy_case
             ::
             (List.map (fun (name, test_f) ->
                 Alcotest_lwt.test_case name `Quick
                    (fun switch () -> run_test_case ~proxy:UseStubServer switch test_f))
                 test_cases
              )
         );
       ]
