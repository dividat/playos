open Tyxml.Html

let section title_str content =
  section
    [ h2 ~a:[ a_class [ "d-Subtitle" ] ] [ txt title_str ]
    ; pre ~a: [ a_class [ "d-Preformatted" ] ]  [ txt content ]
    ]

type params =
  { health: string
  ; update: string
  ; rauc: string
  ; interfaces: string
  }

let html { health; update; rauc; interfaces } =
  Page.html (
    div
      [ h1
          ~a:[ a_class [ "d-Title" ] ]
          [ txt "System Statu"
          ; a
              ~a:[ a_class [ "d-HiddenLink" ]
              ; a_href "/label"
              ]
              [ txt "s" ]
          ]
      ; section "Health" health
      ; section "Update State" update
      ; section "RAUC" rauc
      ; section "Interfaces" interfaces
      ]
  )
