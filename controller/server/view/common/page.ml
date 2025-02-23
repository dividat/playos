open Tyxml.Html

type page =
  | Info
  | Network
  | Localization
  | SystemStatus
  | Changelog
  | Licensing
  | Shutdown

let menu_link page =
  match page with
  | Info ->
      "/info"
  | Network ->
      "/network"
  | Localization ->
      "/localization"
  | SystemStatus ->
      "/status"
  | Changelog ->
      "/changelog"
  | Licensing ->
      "/licensing"
  | Shutdown ->
      "/system/shutdown"

let menu_icon page =
  match page with
  | Info ->
      Icon.info
  | Network ->
      Icon.world
  | Localization ->
      Icon.letter
  | SystemStatus ->
      Icon.screen
  | Changelog ->
      Icon.document
  | Licensing ->
      Icon.copyright
  | Shutdown ->
      Icon.power

let menu_label page =
  match page with
  | Info ->
      "Information"
  | Network ->
      "Network"
  | Localization ->
      "Localization & Display"
  | SystemStatus ->
      "System Status"
  | Changelog ->
      "Changelog"
  | Licensing ->
      "Licensing"
  | Shutdown ->
      "Shutdown"

let menu_item current_page page =
  let is_active = current_page = Some page in
  let class_ =
    "d-Menu__Item" :: (if is_active then [ "d-Menu__Item--Active" ] else [])
  in
  a
    ~a:
      (a_href (menu_link page)
      :: a_class class_
      :: (if is_active then [ a_user_data "focus-active" "" ] else [])
      )
    [ menu_icon page; txt (menu_label page) ]

let html ?current_page ?header content =
  let header =
    match header with
    | Some header ->
        [ Tyxml.Html.header ~a:[ a_class [ "d-Layout__Header" ] ] [ header ] ]
    | None ->
        []
  in
  html
    ~a:[ a_lang "en" ]
    (head
       (title (txt "PlayOS Controller"))
       [ meta ~a:[ a_charset "utf-8" ] ()
       ; link ~rel:[ `Stylesheet ] ~href:"/static/reset.css" ()
       ; link ~rel:[ `Stylesheet ] ~href:"/static/style.css" ()
       ]
    )
    (body
       ~a:[ a_class [ "d-Layout" ] ]
       (aside
          ~a:
            [ a_class [ "d-Layout__Aside" ]
            ; a_user_data "focus-group" "active"
            ]
          [ nav
              ([ Info
               ; Network
               ; Localization
               ; SystemStatus
               ; Changelog
               ; Licensing
               ]
              |> List.concat_map (fun page ->
                     [ menu_item current_page page; txt " " ]
                 )
              )
          ; form
              ~a:
                [ a_action (menu_link Shutdown)
                ; a_method `Post
                ; a_class [ "d-Layout__Shutdown" ]
                ]
              [ button
                  ~a:[ a_class [ "d-Menu__Item" ] ]
                  [ menu_icon Shutdown; txt (menu_label Shutdown) ]
              ]
          ]
        :: header
       @ [ main ~a:[ a_class [ "d-Layout__Main" ] ] [ content ]
         ; script ~a:[ a_src "/static/vendor/focus-shift.js" ] (txt "")
         ; script ~a:[ a_src "/static/client.js" ] (txt "")
         ]
       )
    )

let header_title ?back_url ?icon ?right_action content =
  let back_link =
    match back_url with
    | Some url ->
        [ a
            ~a:[ a_class [ "d-Header__BackLink" ]; a_href url ]
            [ Icon.arrow_left ]
        ]
    | None ->
        []
  in
  let icon =
    match icon with
    | Some icon ->
        [ span ~a:[ a_class [ "d-Header__Icon" ] ] [ icon ] ]
    | None ->
        []
  in
  let right_action =
    match right_action with Some right_action -> [ right_action ] | None -> []
  in
  div
    ~a:[ a_class [ "d-Header__Line" ] ]
    (h1 ~a:[ a_class [ "d-Header__Title" ] ] (back_link @ icon @ content)
    :: right_action
    )
