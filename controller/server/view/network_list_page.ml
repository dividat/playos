open Connman.Service
open Tyxml.Html
open Protocol_conv_jsonm

(* generic utils *)
let sort_by_fun f = List.sort (fun a b -> compare (f a) (f b))

let option_filter f opt = Option.bind opt (fun v -> if f v then Some v else None)

(* page-specific utils *)

let icon_from_interface_kind ?strength kind =
  match kind with
  | Network.Wireless ->
      Icon.wifi ?strength ()
  | Network.Ethernet ->
      Icon.ethernet
  | _ ->
      Icon.world

let icon_from_interface_and_service interface service =
  let strength = Option.bind service (fun s -> s.strength) in
  icon_from_interface_kind ?strength (Network.Interface.kind interface)

let service_ip_addresses service =
  let ipv4 = service.ipv4 |> Option.map (fun (a : IPv4.t) -> a.address) in
  let ipv6 = service.ipv6 |> Option.map (fun (a : IPv6.t) -> a.address) in
  [ ipv4; ipv6 ] |> List.filter_map Fun.id

type interface_entry =
  { display_name : string
  ; interface : Network.Interface.t
  ; annotations : string list
  ; service : Connman.Service.t option
  }

let build_interface_entries services interfaces interface_annotations :
    interface_entry list =
  (* assoc list sorted by key i.e. interface name *)
  let interface_kinds =
    interfaces
    |> List.map (fun (i : Network.Interface.t) ->
        (i.name, Network.Interface.kind i)
    )
    |> sort_by_fun fst
  in
  (* helper for displaying the interface type + index if more than one interface
     of the same type *)
  let resolve_interface_display_name iface =
    let kind = Network.Interface.kind iface in
    let same_kind_ifaces =
      interface_kinds |> List.filter (fun (_, k) -> k = kind)
    in
    let kind_str =
      Network.sexp_of_interface_kind kind |> Sexplib.Sexp.to_string
    in
    if List.length same_kind_ifaces > 1 then
      let index =
        same_kind_ifaces
        |> List.find_index (fun (n, _) -> n = iface.name)
        |> Option.value ~default:0
        |> ( + ) 1
      in
      Format.sprintf "%s %d" kind_str index
    else kind_str
  in
  let non_loopback_ifaces =
    List.filter (fun i -> Network.Interface.kind i <> Loopback) interfaces
  in
  let connected_services =
    List.filter (fun s -> Connman.Service.is_connected s) services
  in
  List.map
    (fun (iface : Network.Interface.t) ->
      { display_name = resolve_interface_display_name iface
      ; interface = iface
      ; annotations =
          List.assoc_opt iface.name interface_annotations
          |> Option.value ~default:[]
      ; service =
          List.find_opt
            (fun service -> service.ethernet.interface = iface.name)
            connected_services
      }
    )
    non_loopback_ifaces

let interface_item { display_name; interface; annotations; service } =
  let icon = icon_from_interface_and_service interface service in
  let is_connected = Option.is_some service in
  let is_link_local =
    service
    |> Option.map Connman.Service.is_link_local
    |> Option.value ~default:false
  in
  let labels =
    (* For pseudo-connected eth interfaces, drop the generic "Wired" service name and only use the annotations *)
    if
      is_link_local
      && Network.Interface.kind interface = Ethernet
      && not (List.is_empty annotations)
    then annotations
    else
      annotations @ (service |> Option.map (fun s -> s.name) |> Option.to_list)
  in
  let ip_addresses =
    service
    |> Option.map service_ip_addresses
    |> option_filter (fun s -> not (List.is_empty s))
    |> Option.value ~default:[ "N/A" ]
    |> List.map (fun v -> div [ txt v ])
  in
  let classes = [ "d-InterfaceList__Item" ] in
  let maybe_wrap_in_link body =
    match service with
    | Some service ->
        a ~a:[ a_class classes; a_href ("/network/" ^ service.id) ] body
    | None ->
        div ~a:[ a_class classes ] body
  in
  li
    [ maybe_wrap_in_link
        [ span
            ~a:[ a_class [ "d-InterfaceList__Marker" ] ]
            [ txt (if is_connected then "✔" else "✖") ]
        ; div ~a:[ a_class [ "d-InterfaceList__Icon" ] ] [ icon ]
        ; span [ txt display_name ]
        ; div
            [ span
                ~a:[ a_class [ "d-InterfaceList__Labels" ] ]
                (labels
                |> List.map (fun label_text ->
                    span
                      ~a:[ a_class [ "d-InterfaceList__Label" ] ]
                      [ txt label_text ]
                )
                )
            ]
        ; span
            ~a:[ a_class [ "d-InterfaceList__Address" ] ]
            [ txt (String.uppercase_ascii interface.address) ]
        ; div ~a:[ a_class [ "d-InterfaceList__Address" ] ] ip_addresses
        ; span
            ~a:[ a_class [ "d-InterfaceList__Chevron" ] ]
            (if is_connected then [ txt "ᐳ" ] else [])
        ]
    ]

let wifi_item ({ id; name; strength } as service) =
  let icon = icon_from_interface_kind ?strength Network.Wireless in
  let is_connected = Connman.Service.is_connected service in
  li
    [ a
        ~a:[ a_class [ "d-WifiList__Item" ]; a_href ("/network/" ^ id) ]
        [ span
            ~a:[ a_class [ "d-WifiList__Marker" ] ]
            [ span [ txt (if is_connected then "✔" else " ") ] ]
        ; div ~a:[ a_class [ "d-WifiList__Icon" ] ] [ icon ]
        ; span [ txt name ]
        ; div ~a:[ a_class [ "d-WifiList__Chevron" ] ] [ txt "ᐳ" ]
        ]
    ]

let render_status_section proxy =
  section
    [ Definition.list ~horizontal:true
        ([ Definition.term [ txt "Internet" ]
         ; Definition.description
             [ div
                 ~a:
                   [ a_class [ "d-Spinner" ]
                   ; Unsafe.string_attrib "is" "internet-status"
                   ]
                 []
             ]
         ]
        @
        match proxy with
        | Some p ->
            [ Definition.term [ txt "Proxy" ]
            ; Definition.description [ txt p ]
            ]
        | None ->
            []
        )
    ]

let render_interface_section (interface_entries : interface_entry list) =
  section
    [ h2 ~a:[ a_class [ "d-Title" ] ] [ txt "Interfaces" ]
    ; ul
        ~a:[ a_class [ "d-InterfaceList" ]; a_role [ "list" ] ]
        ([ li
             ~a:
               [ a_class
                   [ "d-InterfaceList__Item"; "d-InterfaceList__Item--Header" ]
               ]
             [ span [] (* marker *)
             ; span [] (* icon *)
             ; span [ txt "Interface" ]
             ; span [ txt "Connected networks" ]
             ; span [ txt "MAC" ]
             ; span [ txt "IP address" ]
             ; span [] (* chevron *)
             ]
         ]
        @ List.map interface_item interface_entries
        )
    ]

let render_wifi_section services =
  let wireless_services =
    services
    |> List.filter (fun s -> s.type' = Wifi)
    |> sort_by_fun (fun s ->
        (* sort connected items first, then alphanumeric *)
        (Connman.Service.is_connected s |> not, s.name)
    )
  in
  section
    [ h2 ~a:[ a_class [ "d-Title" ] ] [ txt "Available wireless networks" ]
    ; ( if List.is_empty wireless_services then
          p ~a:[ a_class [ "d-Paragraph" ] ] [ txt "No networks available" ]
        else
          ul
            ~a:[ a_class [ "d-WifiList" ]; a_role [ "list" ] ]
            (List.map wifi_item wireless_services)
      )
    ]

type params =
  { proxy : string option
  ; services : Connman.Service.t list
  ; interfaces : Network.Interface.t list
  ; interface_annotations : (string * string list) list
  }
[@@deriving protocol ~driver:(module Jsonm)]

let html { proxy; services; interfaces; interface_annotations } =
  let interface_entries =
    build_interface_entries services interfaces interface_annotations
    |> sort_by_fun (fun entry -> entry.display_name)
  in
  Page.html ~current_page:Page.Network
    ~header:
      (Page.header_title ~icon:Icon.world
         ~right_action:
           (a ~a:[ a_href "/network"; a_class [ "d-Button" ] ] [ txt "Refresh" ])
         [ span [ txt "Network" ] ]
      )
    (div
       [ render_status_section proxy
       ; render_interface_section interface_entries
       ; render_wifi_section services
       ]
    )
