type menu =
  | Info
  | Network
  | Localization
  | Shutdown

val page :
  menu ->
  [< Html_types.main_content_fun > `PCDATA ] Tyxml.Html.elt ->
  [> Html_types.html ] Tyxml.Html.elt
