open Connman.Service
open Tyxml.Html


let proxy_form proxy =
  let open Proxy in
  div
    [ label 
        ~a:[ a_class [ "d-Label" ] ]
        [ txt "Server"
        ; span
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
                ; a_size 10
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
        ]
    ; label 
        ~a:[ a_class [ "d-Label" ] ] 
        [ txt "Username (optional)" 
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
        ]
    ; div
        ~a:(match proxy with
            | Some { credentials = Some { password } } ->
                if password <> "" then
                    [ Unsafe.string_attrib "is" "keep-previous-password" ]
                else
                    []
            | _ -> [])
        [ label
            ~a:[ a_class [ "d-Label" ] ]
            [ txt "Password (optional)"
            ; input
                ~a:[ a_input_type `Password
                ; a_class [ "d-Input"; "d-Network__Input" ]
                ; a_name "proxy_password"
                ; a_value ""
                ; Unsafe.string_attrib "is" "show-password"
                ]
                ()
            ]
        ]
    ]

let maybe_elem cond elem = if cond then Some elem else None

let not_connected_form service =
  let requires_passphrase =  service.security <> [ None ] in
  form
      ~a:[ a_action ("/network/" ^ service.id ^ "/connect")
      ; a_method `Post
      ; Unsafe.string_attrib "is" "disable-after-submit"
      ]
      (Option.to_list (maybe_elem requires_passphrase (
          label
              ~a:[ a_class [ "d-Label" ] ]
              [ txt "Passphrase"
              ; input
                  ~a:[ a_input_type `Password
                  ; a_class [ "d-Input"; "d-Network__Input" ]
                  ; a_name "passphrase"
                  ; Unsafe.string_attrib "is" "show-password"
                  ]
                  ()
              ]
      )) @
      [ p
          [ input
              ~a:[ a_input_type `Submit
              ; a_class [ "d-Button" ]
              ; a_value "Connect"
              ]
              ()
          ]
      ])

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
  let ip_input ~name ~labelTxt ~value ~pattern =
      [ label 
          ~a:[ a_class [ "d-Label" ] ] 
          [ txt labelTxt
          ; input 
              ~a:[ a_value value
               ; a_class [ "d-Input"; "d-Network__Input" ]
               ; a_name name
               ; a_pattern pattern
               ]
               ()
          ]
      ]
  in
  let ipv4_value f =
    if is_static service then
      service.ipv4 |> Option.map (fun (ipv4:IPv4.t) -> f ipv4) |> Option.value ~default:""
    else
      ""
  in
  div
    [ p ~a: [ a_class ["d-Note"]  ][
          txt "A valid IP address must be in the form of "
        ; code ~a:[ a_class [ "d-Code" ] ] [ txt "n.n.n.n" ]
        ; txt ","
        ; br ()
        ; txt "where n is a number in the range of 0-255."
        ]
    ; div ( ip_input
                  ~name:"static_ip_address"
                  ~labelTxt:"Address"
                  ~value:(ipv4_value(fun ipv4 -> ipv4.address))
                  ~pattern:ip_address_regex_pattern
                @ ip_input
                  ~name:"static_ip_netmask"
                  ~labelTxt:"Netmask"
                  ~value:(ipv4_value(fun ipv4 -> ipv4.netmask))
                  ~pattern:ip_address_regex_pattern
                @ ip_input
                  ~name:"static_ip_gateway"
                  ~labelTxt:"Gateway"
                  ~value:(ipv4_value(fun ipv4 -> ipv4.gateway |> Option.value ~default:""))
                  ~pattern:ip_address_regex_pattern
                @ ip_input
                  ~name:"static_ip_nameservers"
                  ~labelTxt:"Nameservers"
                  ~value:(if is_static service then String.concat ", " service.nameservers else "")
                  ~pattern:multi_ip_address_regex_pattern
                @ [ p ~a:[a_class ["d-Note"]][
                    txt  "To set multiple nameservers, use a comma separated list of addresses."
                  ; br ()
                  ; txt "eg. 1.1.1.1, 9.9.9.9"
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
        [ label
            ~a:[ a_class [ "d-CheckboxLabel" ] ]
            [ checked_input
                is_enabled
                [ a_class [ "d-Checkbox" ]
                ; a_input_type `Checkbox
                ; a_name toggle_field
                ; a_onclick "this.closest('.d-Network__ToggleGroup').classList.toggle('d-Network__ToggleGroup--Enabled', this.checked)"
                ]
            ; txt legend_text 
            ]
        ]
    )
    [ fieldset contents ]

let connected_form service =
  div
    [ form
        ~a:[ a_action ("/network/" ^ service.id ^ "/update")
        ; a_method `Post
        ; Unsafe.string_attrib "is" "disable-after-submit"
        ]
        [ toggle_group 
            ~is_enabled:(Option.is_some service.proxy) 
            ~legend_text:"HTTP Proxy" 
            ~toggle_field:"proxy_enabled"
            [ proxy_form service.proxy ]
        ; toggle_group 
            ~is_enabled:(is_static service) 
            ~legend_text:"Static IP" 
            ~toggle_field:"static_ip_enabled"
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
  let is_service_connected = Connman.Service.is_connected service in
  let is_disconnectable = is_service_connected && service.type' = Connman.Technology.Wifi in
  let icon =
    match service.strength with
    | Some s -> Icon.wifi ~strength:s ()
    | None -> Icon.ethernet
  in
  let properties = service
    |> sexp_of_t
    |> Sexplib.Sexp.to_string_hum
  in
  let disconnect_button =
    form
      ~a:[ a_action ("/network/" ^ service.id ^ "/remove")
      ; a_method `Post
      ; Unsafe.string_attrib "is" "disable-after-submit"
      ]
      [ input
          ~a:[ a_input_type `Submit
          ; a_class [ "d-Button" ]
          ; a_value "Forget"
          ]
          ()
      ]
  in
  Page.html 
    ~current_page:Page.Network 
    ~header:(
      Page.header_title 
        ~back_url:"/network" 
        ?right_action:(if is_disconnectable then Some disconnect_button else None)
        ~icon 
        [ txt service.name ])
    (div
      [ if is_service_connected then
          connected_form service
        else
          not_connected_form service
      ; div
          ~a:[ a_class [ "d-Network__Properties" ] ]
          [ h2 ~a:[ a_class [ "d-Title" ] ] [ txt "Service Details" ]
          ; pre
              ~a:[ a_class [ "d-Preformatted" ] ]
              [ txt properties ]
          ]
      ])
