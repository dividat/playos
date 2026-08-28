open Tyxml.Html

let list ?(horizontal = false) ?a =
  let classes =
    [ "d-Definitions" ]
    @ if horizontal then [ "d-Definitions--Horizontal" ] else []
  in
  dl ~a:([ a_class classes ] @ Option.value ~default:[] a)

let term ?a =
  dt ~a:([ a_class [ "d-Definitions__Term" ] ] @ Option.value ~default:[] a)

let description ?a =
  dd
    ~a:
      ([ a_class [ "d-Definitions__Description" ] ] @ Option.value ~default:[] a)
