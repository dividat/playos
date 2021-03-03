type menu_focus =
  | Info
  | Network
  | Localization
  | Shutdown

val html :
  ?menu_focus:menu_focus ->
  [< Html_types.main_content_fun ] Tyxml.Html.elt ->
  [> Html_types.html ] Tyxml.Html.elt
