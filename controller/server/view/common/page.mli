type page =
  | Info
  | Network
  | Localization
  | SystemStatus
  | Changelog
  | Licensing
  | Shutdown

val html :
     ?current_page:page
  -> ?header:[< Html_types.header_content_fun ] Tyxml.Html.elt
  -> [< Html_types.main_content_fun ] Tyxml.Html.elt
  -> [> Html_types.html ] Tyxml.Html.elt

val header_title :
     ?back_url:Tyxml.Html.Xml.uri Tyxml.Html.wrap
  -> ?icon:[< Html_types.span_content_fun ] Tyxml.Html.elt
  -> ?right_action:[< Html_types.div_content_fun > `H1 ] Tyxml.Html.elt
  -> [< Html_types.h1_content_fun > `A `Span ] Tyxml.Html.elt list
  -> [> Html_types.div ] Tyxml.Html.elt
