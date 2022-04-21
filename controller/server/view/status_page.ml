open Tyxml.Html

let definition term description =
  [ Definition.term [ txt term ]
  ; Definition.description [ pre ~a: [ a_class [ "d-Preformatted" ] ]  [ txt description ] ]
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
    (Definition.list
      (definition "Health" health
      @ definition "Update State" update
      @ definition "RAUC" rauc))
