open Connman.Service
open Tyxml.Html

let service_item ({ id; name; strength; ipv4 } as service) =
  let strength =
    match strength with
    | Some s -> [ Signal_strength.html s ]
    | None -> []
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
        ; div
            ~a:[ a_class [ "d-NetworkList__SignalStrength" ] ]
            strength
        ; div ~a:[ a_class [ "d-NetworkList__Chevron" ] ] [ txt "ᐳ" ]
        ]
    ]

type params =
  { proxy: string option
  ; is_internet_connected: bool
  ; services: Connman.Service.t list
  ; interfaces: string
  }

let html { proxy; is_internet_connected; services; interfaces } =
  let connected_services, available_services =
    List.partition Connman.Service.is_connected services
  in
  Page.html ~current_page:Page.Network (
    div
      [ div ~a:[ a_class [ "d-Title" ] ]
           [ div
               ~a:[ a_class [ "d-Network__Title" ] ]
               [ h1 [ txt "Network" ]
               ; div
                   ~a:[ a_class [ "d-Network__TitleAction" ] ]
                   [ a
                       ~a:[ a_href "/network?timeout=3"
                       ; a_class [ "d-Button" ]
                       ]
                       [ txt "Refresh" ]
                   ]
               ]
           ]

      ; section
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
              [ if is_internet_connected then
                  span
                    ~a:[ a_class [ "d-Switch--On" ] ]
                    [ txt "Connected" ]
                else
                  span
                    ~a:[ a_class [ "d-Switch--Off" ] ]
                    [ txt "Not connected" ]
              ]
          ]
        )

      ; section
          [ h2 ~a:[ a_class [ "d-Subtitle" ] ] [ txt "Available Networks" ]
          ; if List.length available_services = 0 then
              txt "No networks available"
            else
              ul
                ~a:[ a_class [ "d-NetworkList" ]; a_role [ "list" ] ]
                (List.map service_item available_services)
          ]

      ; section
          [ h2 ~a:[ a_class [ "d-Subtitle" ] ] [ txt "Network Interfaces" ]
          ; pre ~a: [ a_class [ "d-Preformatted" ] ]  [ txt interfaces ]
          ]
      ]
  )
