open Connman.Service
open Tyxml.Html


let proxy_form proxy =
  let open Proxy in
  div
    [ div ~a:[ a_class [ "d-Network__Label" ] ] [ txt "Server" ]
    ; div
       [ input
         ~a:[ a_input_type `Text
         ; a_class [ "d-Input"; "d-Network__Input" ]
         ; a_name "proxy_host"
         ; a_value
             (match proxy with 
             | Some { host } -> host
             | _ -> ""
             )
         ; a_placeholder "Host"
         ; a_pattern {|[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*|}
         ]
         ()
       ; txt ":"
       ; input
         ~a:[ a_input_type `Number
         ; a_class [ "d-Input" ]
         ; a_name "proxy_port"
         ; a_size 5
         ; a_step (Some 1.0)
         ; a_value
             (match proxy with 
             | Some { port } -> string_of_int port
             | _ -> ""
             )
         ; a_placeholder "Port"
         ]
         ()
       ]
    ; div ~a:[ a_class [ "d-Network__Label" ] ] [ label ~a:[ a_label_for "proxy_user" ] [ txt "Username (optional)" ] ]
    ; input
       ~a:[ a_input_type `Text
       ; a_class [ "d-Input"; "d-Network__Input" ]
       ; a_name "proxy_user"
       ; a_value
           (match proxy with 
           | Some { credentials = Some { user } } -> user
           | _ -> ""
           )
       ]
       ()
    ; div ~a:[ a_class [ "d-Network__Label" ] ] [ label ~a:[ a_label_for "proxy_password" ] [ txt "Password (optional)" ] ]
     ; input
       ~a:[ a_input_type `Password
       ; a_class [ "d-Input"; "d-Network__Input" ]
       ; a_name "proxy_password"
       ; a_value
           (match proxy with 
           | Some { credentials = Some _ } -> "*****"
           | _ -> ""
           )
       ; Unsafe.string_attrib "is" "show-password"
       ]
       ()
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
              [ proxy_form None
              ]
          ]
      ; input
          ~a:[ a_input_type `Submit
          ; a_class [ "d-Button" ]
          ; a_value "Connect"
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

let is_static service =
  service.ipv4
  |> Option.map(fun (ipv4: IPv4.t) -> ipv4.method' = "manual")
  |> Option.value ~default:false

let static_ip_form service =
  let ip_input ~id ~labelTxt ~value ~pattern =
    [ div ~a:[ a_class [ "d-Network__Label" ] ] [ label ~a:[ a_label_for id ] [ txt labelTxt ] ]
    ; input ~a:[ a_id id
               ; a_value value
               ; a_class [ "d-Input"; "d-Network__Input" ]
               ; a_name id
               ; a_pattern pattern
               ]()
    ]
  in
  let ipv4_value f =
    if is_static service then
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
    ; div ( ip_input
                  ~id:"static_ip_address"
                  ~labelTxt:"Address"
                  ~value:(ipv4_value(fun ipv4 -> ipv4.address))
                  ~pattern:ip_address_regex_pattern
                @ ip_input
                  ~id:"static_ip_netmask"
                  ~labelTxt:"Netmask"
                  ~value:(ipv4_value(fun ipv4 -> ipv4.netmask))
                  ~pattern:ip_address_regex_pattern
                @ ip_input
                  ~id:"static_ip_gateway"
                  ~labelTxt:"Gateway"
                  ~value:(ipv4_value(fun ipv4 -> ipv4.gateway |> Option.value ~default:""))
                  ~pattern:ip_address_regex_pattern
                @ ip_input
                  ~id:"static_ip_nameservers"
                  ~labelTxt:"Nameservers"
                  ~value:(if is_static service then String.concat ", " service.nameservers else "")
                  ~pattern:multi_ip_address_regex_pattern
                @ [ p ~a:[a_class ["d-Note"]][
                    txt  "To set multiple nameservers, use a comma separated list of addresses."
                  ; br ()
                  ; txt "eg. 1.1.1.1, 8.8.8.8"
                  ]
                  ]
              )
        ]

let checked_input cond attrs =
  input ~a:(if cond then a_checked () :: attrs else attrs) ()

let toggle_group ~is_enabled ~legend_text ~toggle_field contents =
  fieldset
    ~a:[ a_class ([ "d-Network__ToggleGroup" ] @ if is_enabled then [ "d-Network__ToggleGroup--Enabled" ] else []) ]
    ~legend:(
      legend
        [ checked_input
            is_enabled
            [ a_input_type `Checkbox
            ; a_name toggle_field
            ; a_id toggle_field
            ; a_onclick "this.closest('.d-Network__ToggleGroup').classList.toggle('d-Network__ToggleGroup--Enabled', this.checked)"
            ]
        ; label
            ~a:[ a_label_for toggle_field ]
            [ txt legend_text ]
        ]
    )
    [ fieldset contents ]

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
    ; form
        ~a:[ a_action ("/network/" ^ service.id ^ "/update")
        ; a_method `Post
        ; a_class [ "d-Network__Form" ]
        ; Unsafe.string_attrib "is" "disable-after-submit"
        ]
        [ toggle_group ~is_enabled:(Option.is_some service.proxy) ~legend_text:"HTTP Proxy" ~toggle_field:"proxy_enabled"
            [ proxy_form service.proxy ]
        ; toggle_group ~is_enabled:(is_static service) ~legend_text:"Static IP" ~toggle_field:"static_ip_enabled"
            [ static_ip_form service ]
        ; input
            ~a:[ a_input_type `Submit
            ; a_class [ "d-Button" ]
            ; a_value "Update"
            ]
            ()
        ]
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
