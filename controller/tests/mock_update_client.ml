open Lwt

type state = {
    mutable latest_version: string;
    mutable available_bundles: (string, string) Hashtbl.t ;
    mutable base_url: string;
}

let test_bundle_name = "TEST_PLAYOS_BUNDLE"

class mock failure_generator =
    let return a =
        let%lwt should_fail = failure_generator () in
        if (should_fail) then
            raise (Failure "Random test injected failure!")
        else
            Lwt.return a
    in
    object (self)
    val state = {
        latest_version = "0.0.0";
        available_bundles = Hashtbl.create 5;
        base_url = Config.System.update_url;
    }

    method add_bundle vsn contents =
        Hashtbl.add state.available_bundles vsn contents

    method remove_bundle vsn =
        Hashtbl.remove state.available_bundles vsn

    method set_latest_version vsn =
        state.latest_version <- vsn

    method private gen_stored_bundle_path vsn =
        let prefix = test_bundle_name ^ "_" in
        let suffix = "-" ^ vsn ^ ".raucb" in
        let tmp = Filename.temp_file prefix suffix in
        tmp

    method download vsn =
        let contents = Hashtbl.find state.available_bundles vsn in
        let tmp = self#gen_stored_bundle_path vsn in
        let oc = open_out tmp in
        let () = Printf.fprintf oc "%s\n" contents in
        let () = close_out oc in
        return tmp

    method get_latest_version () =
        return state.latest_version

    method to_module = (module struct
        let download = self#download
        let get_latest_version = self#get_latest_version
    end : Update_client.S)
end
