open Tyxml.Html

let html changelog =
  Page.html (
    div
      ~a:[ a_class [ "d-Markdown" ] ]
      [Unsafe.data changelog]
  )
