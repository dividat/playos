(**
   The mock HTTP server simulates the dist server and provides:
       1) a /latest endpoint for the latest version specified
       2) bundle files for the versions added
   It also supports download resuming via HTTP range requests.
*)
open Opium.Std

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

type range = (int Option.t) * (int Option.t)

let mock_server () = object (self)
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

    method private extract_range_bytes req : range =
        let headers = Request.headers req in
        let range = Cohttp.Header.get headers "Range" in
        match range with
            | Some range_str -> begin
                try
                    let regex = Str.regexp "bytes=\\([0-9]*\\)-\\([0-9]*\\)" in
                    let m = Str.string_match regex range_str 0 in
                    let r_str_to_opt s =
                        if (String.length s > 0) then
                            Some (int_of_string s)
                        else
                            None
                    in
                    if (m) then
                        let range_start = Str.matched_group 1 range_str in
                        let range_end = Str.matched_group 2 range_str in
                        (r_str_to_opt range_start,
                         r_str_to_opt range_end)
                    else
                        failwith @@ "Unsupported range string: " ^ range_str
                with
                    | e ->
                        failwith @@
                            "Failed to parse range headers: " ^ (Printexc.to_string e)
                end
            | None -> (None, None)

    method private range_resp (range_start, range_end) bundle =
        let bundle_bytes = String.to_bytes bundle in
        let total = Bytes.length bundle_bytes in
        let b_start = Option.value ~default:0 range_start in
        let b_end = Option.value ~default:total range_end in
        let bytes_trunc = Bytes.sub bundle_bytes b_start (b_end-b_start) in
        (bytes_trunc, (b_start, b_end, total))

    method private download_bundle_handler req =
          let vsn = Router.param req "vsn" in
          let range = self#extract_range_bytes req in
          let bundle = Hashtbl.find_opt !state.available_bundles vsn in
          let resp = match bundle with
              | Some bund -> begin
                    match range with
                        | (None, None) -> Response.of_string_body bund
                        | _ ->
                            let (bundle_trunc, (b_start, b_end, b_total)) =
                                self#range_resp range bund in
                            let body = bundle_trunc
                                |> Bytes.to_string
                                |> Body.of_string
                            in
                            let headers = Cohttp.Header.of_list
                                [(
                                    "Content-Range",
                                    (Format.sprintf
                                        "bytes %d-%d/%d"
                                        b_start b_end b_total
                                    )
                                )]
                            in
                            Response.create
                                ~headers
                                ~body
                                ()
              end
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
      |> App.get "/ready" (fun (_) -> Lwt.return @@ Response.create ())
      |> App.get "/:vsn/:bundle" self#download_bundle_handler
      |> App.start
      in
      (server_url, server)
end
