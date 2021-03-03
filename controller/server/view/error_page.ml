open Tyxml.Html

type params =
  { exn: string
  ; request: string
  }

let html { exn; request } =
  Page.html (
    div
      [ h1 ~a:[ a_class [ "d-Title" ] ] [ txt "ERROR" ]
      ; pre ~a:[ a_class [ "d-Preformatted" ] ] [ txt exn ]
      ; details
          (summary [ txt "Request" ])
          [ pre ~a: [ a_class [ "d-Preformatted" ] ] [ txt request ]
          ]
      ]
  )
