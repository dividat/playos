open Lwt

type state = {
    mutable latest_version: string;
    mutable available_bundles: (string, string) Hashtbl.t ;
    mutable base_url: string;
}

let test_bundle_name = "TEST_PLAYOS_BUNDLE"

let state : state = {
    latest_version = "0.0.0";
    available_bundles = Hashtbl.create 5;
    base_url = Config.System.update_url;
}

(* TODO: is there a less-copy-paste based approach that avoids using full-blown
   objects? *)
let reset_state () =
    state.latest_version <- "0.0.0";
    state.available_bundles <- Hashtbl.create 5;
    state.base_url <- Config.System.update_url

let add_bundle vsn contents =
    Hashtbl.add state.available_bundles vsn contents

let remove_bundle vsn contents =
    Hashtbl.remove state.available_bundles vsn

let set_latest_version vsn =
    state.latest_version <- vsn

let gen_stored_bundle_path vsn =
    let prefix = test_bundle_name ^ "_" in
    let suffix = "-" ^ vsn ^ ".raucb" in
    (* TODO: this actually creates a temp file - would be good to cleanup
       afterwards *)
    let tmp = Filename.temp_file prefix suffix in
    tmp

let download_url vsn =
    Uri.of_string @@ state.base_url ^ "/" ^ test_bundle_name ^ "-" ^ vsn ^ ".raucb"


let download vsn =
    let contents = Hashtbl.find state.available_bundles vsn in
    let tmp = gen_stored_bundle_path vsn in
    let oc = open_out tmp in
    let () = Printf.fprintf oc "%s\n" contents in
    let () = close_out oc in
    Lwt.return tmp

let get_latest_version () =
    Lwt.return state.latest_version
