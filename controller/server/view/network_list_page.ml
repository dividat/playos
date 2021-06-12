open Connman.Service
open Tyxml.Html

let service { id; name; strength; ipv4 } =
  let strength =
    match strength with
    | Some s -> [ Signal_strength.html s ]
    | None -> []
  in
  li
    [ a
        ~a:[ a_class [ "d-NetworkList__Network" ]
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
  Page.html ~current_page:Page.Network (
    div
      [ h1 ~a:[ a_class [ "d-Title" ] ] [ txt "Network" ]

      ; div
          ~a:[ a_class [ "d-Network__Refresh" ] ]
          [ a
              ~a:[ a_href "/network?timeout=3"
              ; a_class [ "d-Button" ]
              ]
              [ txt "Refresh" ]
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
          [ h2 ~a:[ a_class [ "d-Subtitle" ] ] [ txt "Services" ]
          ; if List.length services = 0 then
              txt "No services available"
            else
              ul ~a:[ a_class [ "d-NetworkList" ] ] (List.map service services)
          ]

      ; section
          [ h2 ~a:[ a_class [ "d-Subtitle" ] ] [ txt "Network Interfaces" ]
          ; pre ~a: [ a_class [ "d-Preformatted" ] ]  [ txt interfaces ]
          ]
      ]
  )
