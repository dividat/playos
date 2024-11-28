open Tyxml.Html

let list ?a =
  dl
    ~a:
      ([ a_class [ "d-Definitions__Definitions" ] ] @ Option.value ~default:[] a)

let term ?a =
  dt ~a:([ a_class [ "d-Definitions__Term" ] ] @ Option.value ~default:[] a)

let description ?a =
  dt
    ~a:
      ([ a_class [ "d-Definitions__Description" ] ] @ Option.value ~default:[] a)
