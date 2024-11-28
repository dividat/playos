type params =
  { message : string
  ; request : string
  }

val html : params -> [> Html_types.html ] Tyxml.Html.elt
