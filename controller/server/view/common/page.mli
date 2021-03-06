type page =
  | Info
  | Network
  | Localization
  | Shutdown

val html :
  ?current_page:page ->
  [< Html_types.main_content_fun ] Tyxml.Html.elt ->
  [> Html_types.html ] Tyxml.Html.elt
