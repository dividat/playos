open Tyxml.Html

type menu_focus =
  | Info
  | Network
  | Localization
  | Shutdown

let menu_link menu_focus =
  match menu_focus with
  | Info -> "/info"
  | Network -> "/network"
  | Localization -> "/localization"
  | Shutdown -> "/shutdown"

let menu_icon menu_focus =
  match menu_focus with
  | Info -> "/static/info.svg"
  | Network -> "/static/wifi.svg"
  | Localization -> "/static/world.svg"
  | Shutdown -> "/static/power.svg"

let menu_alt menu_focus =
  match menu_focus with
  | Info -> "Information"
  | Network -> "Network"
  | Localization -> "Localization"
  | Shutdown -> "Shutdown"

let menu_item menu_focus m =
  let class_ =
    "d-Menu__Item" ::
      (if menu_focus = Some m then [ "d-Menu__Item--Active" ] else [])
  in
  div
    ~a:[ a_class class_ ]
    [ a
        ~a:[ a_href (menu_link m) ]
        [ img
            ~src:(menu_icon m)
            ~alt:(menu_alt m)
            ~a:[ a_class [ "d-Menu__ItemIcon" ] ]
            ()
        ]
    ]

let html ?menu_focus content =
  html
    ~a:[ a_lang "en" ]
    (head
        (title (txt "PlayOS Controller"))
        [ meta ~a:[ a_charset "utf-8" ] ()
        ; link ~rel:[`Stylesheet] ~href:"/static/reset.css" ()
        ; link ~rel:[`Stylesheet] ~href:"/static/style.css" ()
        ]
    )
    (body
      ~a:[ a_class [ "d-Container" ] ]
      [ header ~a:[ a_class [ "d-Header" ] ] []
      ; nav
          ~a:[ a_class [ "d-Menu" ] ]
          ([ Info; Network; Localization; Shutdown ]
              |> List.map (menu_item menu_focus))
      ; main
          ~a:[ a_class [ "d-Content" ] ]
          [ content ]
      ; footer
          ~a:[ a_class [ "d-Footer" ] ]
          [ a
              ~a:[ a_href "/changelog"
              ; a_class [ "d-Footer__Link" ]
              ]
              [ txt "changelog" ]
          ; a
              ~a:[ a_href "/status"
              ; a_class [ "d-Footer__Link" ]
              ]
              [ txt "system status" ]
          ]
      ]
    )
