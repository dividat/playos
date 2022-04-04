open Connman.Service
open Tyxml.Html

let proxy_id service_id =
  "proxy-" ^ service_id

let proxy_label service_id =
  div
    ~a:[ a_class [ "d-Network__Label" ] ]
    [ label
        ~a:[ a_label_for (proxy_id service_id) ]
        [ txt "URL" ]
    ]

let proxy_input ?proxy service_id =
  input
    ~a:[ a_input_type `Text
    ; a_id (proxy_id service_id)
    ; a_class [ "d-Input"; "d-Network__Input" ]
    ; a_name "proxy"
    ; a_value (Option.value ~default:"" proxy)
    ]
    ()

let proxy_form_note =
  p
    ~a:[ a_class [ "d-Note" ] ]
    [ txt "URL in the form "
    ; em ~a:[ a_class [ "d-Code" ] ] [ txt "http://host:port" ]
    ; txt " or "
    ; em ~a:[ a_class [ "d-Code" ] ] [ txt "http://user:password@host:port" ]
    ; txt "."
    ]

let not_connected_form service =
  let passphrase_id = "passphrase-" ^ service.id in
  form
      ~a:[ a_action ("/network/" ^ service.id ^ "/connect")
      ; a_method `Post
      ; a_class [ "d-Network__Form" ]
      ; Unsafe.string_attrib "is" "disable-after-submit"
      ]
      [ div
          ~a:[ a_class [ "d-Network__Label" ] ]
          [ label
              ~a:[ a_label_for passphrase_id ]
              [ txt "Passphrase" ]
          ]
      ; input
          ~a:[ a_input_type `Password
          ; a_class [ "d-Input"; "d-Network__Input" ]
          ; a_id passphrase_id
          ; a_name "passphrase"
          ; Unsafe.string_attrib "is" "show-password"
          ]
          ()
      ; details
          ~a:[ a_class [ "d-Details" ] ]
          (summary [ txt "Proxy Settings" ])
          [ div
              ~a:[ a_class [ "d-Network__AdvancedSettingsTitle" ] ]
              [ proxy_label service.id
              ; proxy_input service.id
              ; proxy_form_note
              ]
          ]
      ; input
          ~a:[ a_input_type `Submit
          ; a_class [ "d-Button" ]
          ; a_value "Connect"
          ]
          ()
      ]

let disable_proxy_form service =
  form
      ~a:[ a_action ("/network/" ^ service.id ^ "/proxy/remove")
      ; a_method `Post
      ; Unsafe.string_attrib "is" "disable-after-submit"
      ]
      [ input
          ~a:[ a_input_type `Submit
          ; a_class [ "d-Button" ]
          ; a_value "Disable proxy"
          ]
          ()
      ]

(* Regex pattern to validate IP addresses
 * From: https://stackoverflow.com/a/36760050 *)
let ip_address_regex_pattern =
  {|^((25[0-5]|(2[0-4]|1[0-9]|[1-9]|)[0-9])(\.(?!$)|$)){4}$|}

(* Regex pattern to match single IP address or a comma separated list of IP addresses *)
let multi_ip_address_regex_pattern =
  {|(((((25[0-5]|(2[0-4]|1[0-9]|[1-9]|)[0-9])(\.(?!$)|\b)){4}))(,( +)?)?)+|}


let static_ip_form service =
  let is_static =
    service.ipv4
    |> Option.map(fun (ipv4: IPv4.t) -> ipv4.method' = "manual")
    |> Option.value ~default:false
  in
  let ip_input ~id ~labelTxt ~name ~value ~pattern =
    [
      div ~a:[ a_class [ "d-Network__Label" ] ] [ label ~a:[ a_label_for id ] [ txt labelTxt ] ]
    ; input ~a:[ a_id id
               ; a_value value
               ; a_class [ "d-Input"; "d-Network__Input" ]
               ; a_name name
               ; a_required ()
               ; a_pattern pattern
               ]()
    ]
  in
  let ipv4_value f =
    if is_static then
      service.ipv4 |> Option.map (fun (ipv4:IPv4.t) -> f ipv4) |> Option.value ~default:""
    else
      ""
  in
  div ~a:[ a_class [ "d-Network__Form" ]]
    [ p ~a: [ a_class ["d-Note"]  ][
          txt "A valid IP address must be in the form of "
        ; code ~a:[ a_class [ "d-Code" ] ] [ txt "n.n.n.n" ]
        ; txt ","
        ; br ()
        ; txt "where n is a number in the range of 0-255."
        ]
    ; form ~a:[ a_action ("/network/" ^ service.id ^ "/static-ip/update")
              ; a_id "static-ip-form"
              ; a_method `Post
              ; Unsafe.string_attrib "is" "disable-after-submit"
              ]
        [ div ( ip_input
                  ~id:"static-ip-address"
                  ~labelTxt:"Address"
                  ~name:"address"
                  ~value:(ipv4_value(fun ipv4 -> ipv4.address))
                  ~pattern:ip_address_regex_pattern
                @ ip_input
                  ~id:"static-ip-netmask"
                  ~labelTxt:"Netmask"
                  ~name:"netmask"
                  ~value:(ipv4_value(fun ipv4 -> ipv4.netmask))
                  ~pattern:ip_address_regex_pattern
                @ ip_input
                  ~id:"static-ip-gateway"
                  ~labelTxt:"Gateway"
                  ~name:"gateway"
                  ~value:(ipv4_value(fun ipv4 -> ipv4.gateway |> Option.value ~default:""))
                  ~pattern:ip_address_regex_pattern
                @ ip_input
                  ~id:"static-ip-nameservers"
                  ~labelTxt:"Nameservers"
                  ~name:"nameservers"
                  ~value:(if is_static then String.concat ", " service.nameservers else "")
                  ~pattern:multi_ip_address_regex_pattern
                @ [ p ~a:[a_class ["d-Note"]][
                    txt  "To set multiple nameservers, use a comma separated list of addresses."
                  ; br ()
                  ; txt "eg. 1.1.1.1, 8.8.8.8"
                  ]
                  ]
              )
        ]
    ; div
        [ input ~a:[ a_value "Update"
                     ; a_form "static-ip-form"
                     ; a_input_type `Submit
                     ; a_class [ "d-Button" ]
                     ]()
          ; if is_static then
              form ~a:[ a_action ( "/network/" ^ service.id ^ "/static-ip/remove" )
                      ; a_method `Post
                      ; a_style "display: inline; margin-left: 0.5rem"
                      ; Unsafe.string_attrib "is" "disable-after-submit"
                      ]
                [ input ~a:[ a_value "Remove"
                           ; a_input_type `Submit
                           ; a_class [ "d-Button" ]
                           ]()
                ]
            else
              txt ""
          ]
    ]


let connected_form service =
  div
    [ form
        ~a:[ a_action ("/network/" ^ service.id ^ "/remove")
        ; a_method `Post
        ; a_class [ "d-Network__Form" ]
        ; Unsafe.string_attrib "is" "disable-after-submit"
        ]
        [ input
            ~a:[ a_input_type `Submit
            ; a_class [ "d-Button" ]
            ; a_value "Remove"
            ]
            ()
        ]
    ; details
        ~a:[ a_class [ "d-Details" ] ]
        (summary [ txt "Proxy Settings" ])
        [ div
            ~a:[ a_class [ "d-Network__Form" ] ]
            [ proxy_label service.id
            ; div
                ~a:[ a_class [ "d-Network__ProxyForm" ] ]
                [ form
                    ~a:[ a_action ("/network/" ^ service.id ^ "/proxy/update")
                    ; a_method `Post
                    ; a_class [ "d-Network__ProxyUpdate" ]
                    ; Unsafe.string_attrib "is" "disable-after-submit"
                    ]
                    [ proxy_input ?proxy:service.proxy service.id
                    ; input
                        ~a:[ a_input_type `Submit
                        ; a_class [ "d-Button" ]
                        ; a_value "Update"
                        ]
                        ()
                    ]
                ; (if Option.is_some service.proxy then
                    disable_proxy_form service
                  else
                    txt "")
                ]
            ; proxy_form_note
            ]
        ]

    ; details ~a:[ a_class [ "d-Details" ] ] (summary [ txt "Static IP" ])
      [ static_ip_form service ]
    ]

let html service =
  let strength =
    match service.strength with
    | Some s ->
        div
            ~a:[ a_class [ "d-Network__SignalStrength" ] ]
            [ Signal_strength.html s ]
    | None ->
        div []
  in
  let properties = service
    |> sexp_of_t
    |> Sexplib.Sexp.to_string_hum
  in
  Page.html ~current_page:Page.Network (
    div
      [ a ~a:[
          a_class [ "d-BackLink" ]
          ; a_href "/network"
          ]
          [ txt "Back to networks" ]
      ; div
          ~a:[ a_class [ "d-Title" ] ]
          [ div
              ~a:[ a_class [ "d-Network__Title" ] ]
              [ h1 [ txt service.name ]
              ; strength
              ]
          ]
      ; div
          ~a:[ a_class [ "d-Network__Properties" ] ]
          [ pre
              ~a:[ a_class [ "d-Preformatted" ] ]
              [ txt properties ]
          ]
      ; if Connman.Service.is_connected service then
          connected_form service
        else
          not_connected_form service
      ]
  )
