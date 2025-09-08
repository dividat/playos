open Protocol_conv_jsonm

type params =
  { proxy : string option
  ; services : Connman.Service.t list
  ; interfaces : Network.Interface.t list
  ; interface_annotations : (string * string list) list
  }
[@@deriving protocol ~driver:(module Jsonm)]

val html : params -> [> Html_types.html ] Tyxml.Html.elt
