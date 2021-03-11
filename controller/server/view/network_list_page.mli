type params =
  { proxy: string option
  ; is_internet_connected: bool
  ; services: Connman.Service.t list
  }

val html :
  params
  -> [> Html_types.html ] Tyxml.Html.elt
