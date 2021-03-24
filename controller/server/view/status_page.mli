type params =
  { health: string
  ; update: string
  ; rauc: string
  ; interfaces: string
  }

val html :
  params
  -> [> Html_types.html ] Tyxml.Html.elt
