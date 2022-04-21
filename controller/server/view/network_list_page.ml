open Connman.Service
open Tyxml.Html

let service_item ({ id; name; strength; ipv4 } as service) =
  let icon =
    match strength with
    | Some s -> Icon.wifi ~strength:s ()
    | None -> Icon.ethernet
  in
  let
    classes =
      [ "d-NetworkList__Network" ]
        @ if Connman.Service.is_connected service then [ "d-NetworkList__Network--Connected" ] else []
  in
  li
    [ a
        ~a:[ a_class classes
        ; a_href ("/network/" ^ id)
        ]
        [ div [ txt name ]
        ; (match ipv4 with
          | Some ipv4_addr ->
                div ~a:[ a_class [ "d-NetworkList__Address" ] ] [ txt (ipv4_addr.address) ]
          | None ->
                space ()
          )
        ; div ~a:[ a_class [ "d-NetworkList__Icon" ] ] [ icon ]
        ; div ~a:[ a_class [ "d-NetworkList__Chevron" ] ] [ txt "ᐳ" ]
        ]
    ]

type params =
  { proxy: string option
  ; services: Connman.Service.t list
  ; interfaces: string
  }

let html { proxy; services; interfaces } =
  let connected_services, available_services =
    List.partition Connman.Service.is_connected services
  in
  Page.html 
    ~current_page:Page.Network 
    ~header:(
      Page.header_title 
        ~icon:Icon.world
        ~right_action:(a ~a:[ a_href "/network" ; a_class [ "d-Button" ] ] [ txt "Refresh" ])
        [ txt "Network" ])
    (div
      [ if List.length connected_services = 0 then
          txt ""
        else
          section
            [ ul
                ~a:[ a_class [ "d-NetworkList" ]; a_role [ "list" ] ]
                (List.map service_item connected_services)
            ]

      ; Definition.list (
          (match proxy with
          | Some p ->
              [ Definition.term [ txt "Proxy" ]
              ; Definition.description [ txt p ]
              ]
          | None ->
              []
          ) @
          [ Definition.term [ txt "Internet" ]
          ; Definition.description 
              [ div 
                  ~a:[ a_class [ "d-Spinner" ]
                  ; Unsafe.string_attrib "is" "internet-status" 
                  ]
                  [] 
              ]
          ]
        )

      ; section
          [ h2 ~a:[ a_class [ "d-Subtitle" ] ] [ txt "Available Networks" ]
          ; if List.length available_services = 0 then
              p ~a:[ a_class [ "d-Paragraph" ] ] [ txt "No networks available" ]
            else
              ul
                ~a:[ a_class [ "d-NetworkList" ]; a_role [ "list" ] ]
                (List.map service_item available_services)
          ]

      ; section
          [ h2 ~a:[ a_class [ "d-Subtitle" ] ] [ txt "Network Interfaces" ]
          ; pre ~a: [ a_class [ "d-Preformatted" ] ]  [ txt interfaces ]
          ]
      ])
