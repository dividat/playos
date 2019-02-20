open Lwt
open Sexplib.Std
open Opium_kernel.Rock
open Opium.App

let log_src = Logs.Src.create "gui"

(* Helper to load file *)
let of_file f =
  let%lwt ic = Lwt_io.(open_file ~mode:Lwt_io.Input) f in
  let%lwt template_f = Lwt_io.read ic in
  let%lwt () = Lwt_io.close ic in
  template_f
  |> Mustache.of_string
  |> return

(* Load a template file

   TODO: cache templates
*)
let template name =
  let open Fpath in
  let template_dir =
    (Sys.argv.(0) |> v |> parent) / ".." / "share" / "template"
  in
  template_dir / (name ^ ".mustache")
  |> to_string
  |> of_file

(* Helper to render template *)
let render name dict =
  let%lwt template = template name in
  Mustache.render ~strict:false template (Ezjsonm.dict dict)
  |> return

(* Middleware that makes static content available *)
let static () =
  (* Require the static content to be at a directory fixed to the binary location. This is not optimal, but works for the moment. TODO: figure out a better way to do this.
  *)
  let static_dir =
    Fpath.(
      (Sys.argv.(0) |> v |> parent) / ".." / "share" / "static"
      |> to_string
    )
  in
  Logs.debug (fun m -> m "static content dir: %s" static_dir);
  Opium.Middleware.static ~local_path:static_dir ~uri_prefix:"/static" ()

(* Main page *)
let index content =
  render "index" ["content", content |> Ezjsonm.string]
  >|= Response.of_string_body

let page identifier page_values =
  let menu_flag = ( "is_" ^ identifier, Ezjsonm.bool true ) in
  let index_with_menu_flag content =
    render "index" (menu_flag :: ["content", content |> Ezjsonm.string])
  in
  render identifier page_values
  >>= index_with_menu_flag
  >|= Response.of_string_body

let success msg =
  msg
  |> index

(* Pretty error printing middleware *)
let error_handling =
  let open Opium_kernel.Rock in
  let filter handler req =
    match%lwt handler req |> Lwt_result.catch with
    | Ok res ->
      return res
    | Error exn ->
      let%lwt () = Logs_lwt.err (fun m -> m "GUI Error: %s" (Printexc.to_string exn)) in
      page "error"
        Ezjsonm.([
            "exn", exn
                   |> Sexplib.Std.sexp_of_exn
                   |> Sexplib.Sexp.to_string_hum
                   |> string
          ; "request", req
                       |> Request.sexp_of_t
                       |> Sexplib.Sexp.to_string_hum
                       |> string
          ])
  in
  Middleware.create ~name:"Error" ~filter

(** Display basic server information *)
module InfoGui = struct
  let build app =
    app
    |> get "/info" (fun _ ->
        let%lwt server_info = Info.get () in
        page "info" [ "server_info", server_info |> Info.to_json ])
end

(** Network configuration GUI *)
module NetworkGui = struct

  open Connman
  open Network

  let overview
      ~(connman:Manager.t)
      ~(internet:Internet.state Lwt_react.S.t)
      req =

    (* Check if internet connected *)
    let%lwt internet_connected =
      if
        internet
        |> Lwt_react.S.value
        |> Internet.is_connected
      then
        return true
      else
        (* If not connected delay for 3 seconds.

           Motivation: Add a delay after connecting to a new service.
        *)
        let%lwt () = Lwt_unix.sleep 3.0 in
        internet
        |> Lwt_react.S.value
        |> Internet.is_connected
        |> return
    in

    let%lwt services =
      Manager.get_services connman
      (* If not connected show all services, otherwise show services that are connected *)
      >|= List.filter (fun s -> not internet_connected || s |> Service.is_connected)
    in


    page "network"
      [
        "internet_connected", internet_connected |> Ezjsonm.bool
      ; "services", services |> Ezjsonm.list (fun s -> s |> Service.to_json |> Ezjsonm.value)
      ]

  (** Helper to find a service by id *)
  let find_service ~connman id =
    let open Connman in
    Connman.Manager.get_services connman
    >|= List.find_opt (fun (s:Service.t) -> s.id = id)

  (** Connect to a service *)
  let connect ~(connman:Connman.Manager.t) req =
    let service_id = param req "id" in
    let%lwt form_data =
      urlencoded_pairs_of_body req
    in
    let input =
      match form_data |> List.assoc_opt "passphrase" with
      | Some [ passphrase ] ->
        Connman.Agent.Passphrase passphrase
      | _ ->
        Connman.Agent.None
    in
    match%lwt find_service ~connman service_id with
    | None ->
      fail_with (Format.sprintf "Service does not exist (%s)" service_id)
    | Some service ->
      Connman.Service.connect ~input service
      >|= (fun () -> Format.sprintf "Connected with %s." service.name)
      >>= success

  let remove ~(connman:Connman.Manager.t) req =
    let service_id = param req "id" in
    match%lwt find_service ~connman service_id with
    | None ->
      fail_with (Format.sprintf "Service does not exist (%s)" service_id)
    | Some service ->
      Connman.Service.remove service
      >|= (fun () -> Format.sprintf "Removed service %s." service.name)
      >>= success

  let build
      ~(connman:Connman.Manager.t)
      ~(internet:Network.Internet.state Lwt_react.S.t)
      app =
    app
    |> get "/network" (overview ~connman ~internet)
    |> post "/network/:id/connect" (connect ~connman)
    |> post "/network/:id/remove" (remove ~connman)

end


(** Label printing *)
module LabelGui = struct
  open Label_printer

  let make_label () =
    let%lwt ethernet_interfaces =
      Network.Interface.get_all ()
      >|= List.filter (fun (i: Network.Interface.t) ->
          Re.execp (Re.seq [Re.start; Re.str "enp" ] |> Re.compile) i.name)
    in
    let%lwt server_info = Info.get () in
    return
      ({ machine_id = server_info.machine_id
       ; mac_1 = CCOpt.(
             ethernet_interfaces
             |> CCList.get_at_idx 0
             >|= (fun i -> i.address)
             |> get_or ~default:"-"
           )
       ; mac_2 = CCOpt.(
             ethernet_interfaces
             |> CCList.get_at_idx 1
             >|= (fun i -> i.address)
             |> get_or ~default:"-"
           )
       } : Label_printer.label)

  let overview req =
    let%lwt label = make_label () in
    page "label"
      [ "machine_id", label.machine_id |> Ezjsonm.string
      ; "mac_1", label.mac_1 |> Ezjsonm.string
      ; "mac_2", label.mac_2 |> Ezjsonm.string
      ; "default_label_printer_url",
        "http://pinocchio.local:3000/play-computer" |> Ezjsonm.string
      ]

  let print req =
    let%lwt form_data = urlencoded_pairs_of_body req in
    let url = form_data
              |> List.assoc "label_printer_url"
              |> List.hd
    in
    let count = form_data
                |> List.assoc "count"
                |> List.hd
                |> int_of_string
    in
    let%lwt label = make_label () in
    CCList.replicate count ()
    |> Lwt_list.iter_s
      (fun () -> Label_printer.print ~url label)
    >|= (fun () -> "Labels printed.")
    >>= success

  let build app =
    app
    |> get "/label" overview
    |> post "/label/print" print

end

module StatusGui = struct
  let build ~health_s ~update_s ~rauc app =
    app
    |> get "/status" (fun req ->
        let%lwt rauc =
          catch
            (fun () -> Rauc.get_status rauc
              >|= Rauc.sexp_of_status
              >|= Sexplib.Sexp.to_string_hum)
            (fun exn -> Printexc.to_string exn
                        |> return)
        in
        let%lwt interfaces = Network.Interface.get_all () in
        page "status" [
          "update", update_s
                    |> Lwt_react.S.value
                    |> Update.sexp_of_state
                    |> Sexplib.Sexp.to_string_hum
                    |> Ezjsonm.string
        ; "rauc", rauc
                  |> Ezjsonm.string
        ; "health", health_s
                    |> Lwt_react.S.value
                    |> Health.sexp_of_state
                    |> Sexplib.Sexp.to_string_hum
                    |> Ezjsonm.string
        ; "interfaces", interfaces
                        |> [%sexp_of: Network.Interface.t list]
                        |> Sexplib.Sexp.to_string_hum
                        |> Ezjsonm.string
        ]
      )
end

let routes ~shutdown ~health_s ~update_s ~rauc ~connman ~internet app =
  app
  |> middleware (static ())
  |> middleware error_handling

  |> get "/" (fun _ -> "/info" |> Uri.of_string |> redirect')

  |> get "/shutdown" (fun _ ->
      shutdown ()
      >|= (fun _ -> `String "Ok")
      >|= respond
    )

  |> InfoGui.build
  |> NetworkGui.build ~connman ~internet
  |> LabelGui.build
  |> StatusGui.build ~health_s ~update_s ~rauc

(* NOTE: probably easier to create a record with all the inputs instead of passing in x arguments. *)
let start ~port ~shutdown ~health_s ~update_s ~rauc ~connman ~internet =
  empty
  |> Opium.App.port port
  |> routes ~shutdown ~health_s ~update_s ~rauc ~connman ~internet
  |> start
