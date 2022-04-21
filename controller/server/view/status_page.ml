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
  }

let html { health; update; rauc } =
  Page.html 
    ~current_page:Page.SystemStatus 
    ~header:(Page.header_title 
      ~icon:Icon.screen 
      [ txt "System Statu"
      ; a
          ~a:[ a_class [ "d-HiddenLink" ]
          ; a_href "/label"
          ]
          [ txt "s" ]
      ])
    (div
      [ section "Health" health
      ; section "Update State" update
      ; section "RAUC" rauc
      ])
