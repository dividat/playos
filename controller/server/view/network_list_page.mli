type params =
  { proxy: string option
  ; services: Connman.Service.t list
  ; interfaces: Network.Interface.t list
  }
  [@@deriving yojson]

val html :
  params
  -> [> Html_types.html ] Tyxml.Html.elt
