open Opium.Std
open Lwt
open Update_client

module StubServer = struct
    type state = {
        mutable latest_version: string;
        mutable available_bundles: (string, string) Hashtbl.t ;
    }

    let state : state = {
        latest_version = "0.0.0";
        available_bundles = Hashtbl.create 5;
    }

    let reset_state () =
        state.latest_version <- "0.0.0";
        state.available_bundles <- Hashtbl.create 5

    let add_bundle vsn contents =
        Hashtbl.add state.available_bundles vsn contents

    let remove_bundle vsn contents =
        Hashtbl.remove state.available_bundles vsn

    let set_latest_version vsn =
        state.latest_version <- vsn

    let get_latest_handler _req =
        let resp = Response.of_string_body
            state.latest_version
        in
        Lwt.return resp

    let download_bundle_handler req =
        let vsn = Router.param req "vsn" in
        let bundle = Hashtbl.find_opt state.available_bundles vsn in
        let resp = match bundle with
            | Some bund -> Response.of_string_body bund
            | None -> Response.of_string_body ~code:`Not_found
                "Bundle version not found"
        in
        Lwt.return resp

    let run () =
      let server = App.empty
     (* TODO: should bind to random available port instead, but
        it seems it is not possible with opium/cohttp *)
      |> App.port 9999
      |> App.get "/latest" get_latest_handler
      |> App.get "/:vsn/:bundle" download_bundle_handler
      |> App.start
      in
      ("http://localhost:9999/", server)
end


let setup_log () =
  Fmt_tty.setup_std_outputs ();
  Logs.set_level @@ Some Logs.Debug;
  Logs.set_reporter (Logs_fmt.reporter ());
  ()

let reset_mocks () = begin
end

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
                (server_url |> Uri.of_string |> Option.some),
                (* Note: DO NOT use https here, because curl will attempt
                   to CONNECT and then this whole setup doesn't work *)
                "http://some-invalid-url.local/"
            )
        | Custom p ->
            (
                (p |> Uri.of_string |> Option.some),
                server_url
            )

let run_test_case ?(proxy = NoProxy) switch f =
    let () = reset_mocks ()  in
    let (server_url, server_task) = StubServer.run () in
    Lwt_switch.add_hook (Some switch)
        (fun () -> Lwt.return @@ Lwt.cancel server_task);
    let (proxy_url, base_url) = process_proxy_spec proxy server_url in
    let module ConfigI = (val Update_client.make_config ?proxy:proxy_url base_url) in
    let module UpdateC = Update_client.Make (ConfigI) in
    f (module UpdateC : UpdateClientIntf)

let test_get_version_ok (module Client : UpdateClientIntf) =
    let expected_version = "1.0.0" in
    let () = StubServer.set_latest_version expected_version in
    let%lwt vsn = Client.get_latest_version () in
    return @@ Alcotest.(check string)
        "Latest version is fetched"
        expected_version
        vsn

let read_file file = In_channel.with_open_bin file In_channel.input_all

let test_download_bundle_ok (module Client : UpdateClientIntf) =
    let version = "1.0.0" in
    let bundle = "BUNDLE_CONTENTS" in
    let () = StubServer.add_bundle version bundle in
    let url = Client.download_url version in
    let%lwt bundle_path = Client.download url version in
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
let test_invalid_proxy_fail (module Client : UpdateClientIntf) =
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
