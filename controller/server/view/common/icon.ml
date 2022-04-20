open Tyxml.Svg

(* Helpers *) 

let svg ?a content =
  Tyxml.Html.svg 
    ~a:([ a_viewBox (0., 0., 24., 24.) 
    ; a_width (24., None)
    ; a_height (24., None)
    ; a_fill `None
    ; a_stroke `CurrentColor
    ; a_stroke_width (2., None)
    ; a_stroke_linecap `Round
    ; a_stroke_linejoin `Round
    ] @ (Option.value ~default:[] a))
    content

let line (x1, y1) (x2, y2) =
  Tyxml.Svg.line 
    ~a:[ a_x1 (x1, None) 
    ; a_y1 (y1, None) 
    ; a_x2 (x2, None) 
    ; a_y2 (y2, None) 
    ] 
    []

let circle (x, y) r =
  Tyxml.Svg.circle 
    ~a:[ a_cx (x, None) 
    ; a_cy (y, None) 
    ; a_r (r, None) 
    ]
    []

let rect ?rx (x1, y1) (x2, y2) =
    Tyxml.Svg.rect 
      ~a:[ a_x (x1, None) 
      ; a_y (y1, None) 
      ; a_width (x2 -. x1, None) 
      ; a_height (y2 -. y1, None) 
      ; a_rx (Option.value ~default:0. rx, None) 
      ] 
      []

(* Icons *)

let info =
  svg
    [ circle (12., 12.) 10.
    ; line (12., 16.) (12., 12.)
    ; line (12., 8.) (12., 8.)
    ]

let wifi ?strength () =
  let strength = Option.value ~default:100 strength in
  let modifier =
    if strength < 25 then "None"
    else if strength < 50 then "Weak"
    else if strength < 75 then "Medium"
    else "Strong"
  in
  svg 
    ~a:[ a_class [ "d-WifiSignal--" ^ modifier ] ]
    [ path ~a:[ a_class [ "d-WifiSignal__Wave--Outer" ] ; a_d "M1.42 9a16 16 0 0 1 21.16 0" ] []
    ; path ~a:[ a_class [ "d-WifiSignal__Wave--Middle" ] ; a_d "M5 12.55a11 11 0 0 1 14.08 0" ] []
    ; path ~a:[ a_class [ "d-WifiSignal__Wave--Inner" ] ; a_d "M8.53 16.11a6 6 0 0 1 6.95 0" ] []
    ; line (12., 20.) (12., 20.)
    ]

let world =
  svg
    [ circle (12., 12.) 10.
    ; line (2., 12.) (22., 12.)
    ; path ~a:[ a_d "M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z" ] []
    ]

let power =
  svg
    [ path ~a:[ a_d "M18.36 6.64a9 9 0 1 1-12.73 0" ] []
    ; line (12., 2.) (12., 12.)
    ]

let screen = 
  svg
    [ rect ~rx:2. (2.5, 2.) (21.5, 16.)
    ; line (12., 16.) (12., 22.)
    ; line (8., 22.) (16., 22.)
    ]

let document = 
  svg
    [ rect ~rx:1. (4., 2.) (20., 22.)
    ; line (8., 8.) (16., 8.)
    ; line (8., 12.) (16., 12.)
    ; line (8., 16.) (16., 16.)
    ]
