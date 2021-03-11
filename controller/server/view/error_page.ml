open Tyxml.Html

type params =
  { message: string
  ; request: string
  }

let html { message; request } =
  Page.html (
    div
      [ h1 ~a:[ a_class [ "d-Title" ] ] [ txt "ERROR" ]
      ; pre ~a:[ a_class [ "d-Preformatted" ] ] [ txt message ]
      ; details
          (summary [ txt "Request" ])
          [ pre ~a: [ a_class [ "d-Preformatted" ] ] [ txt request ]
          ]
      ]
  )
