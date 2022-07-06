type params =
  { proxy: string option
  ; services: Connman.Service.t list
  ; interfaces: string
  }

val html :
  params
  -> [> Html_types.html ] Tyxml.Html.elt
