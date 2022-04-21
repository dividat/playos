open Tyxml.Html

let html changelog =
  Page.html 
    ~current_page:Page.Changelog 
    ~header:(Page.header_title ~icon:Icon.document [ txt "Changelog" ])
    (div
      ~a:[ a_class [ "d-Markdown" ] ]
      [ Unsafe.data changelog ])
