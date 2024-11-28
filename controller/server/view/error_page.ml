open Tyxml.Html

type params =
  { message : string
  ; request : string
  }

let html { message; request } =
  Page.html
    ~header:(Page.header_title [ txt "Error" ])
    (div
       [ pre ~a:[ a_class [ "d-Preformatted" ] ] [ txt message ]
       ; details
           (summary [ txt "Request" ])
           [ pre ~a:[ a_class [ "d-Preformatted" ] ] [ txt request ] ]
       ]
    )
