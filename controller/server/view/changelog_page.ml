open Tyxml.Html

let html changelog =
  Page.html ~current_page:Page.Changelog (
    div
      ~a:[ a_class [ "d-Markdown" ] ]
      [Unsafe.data changelog]
  )
