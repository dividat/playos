open Tyxml.Svg

let modifier s =
  if s < 25 then "None"
  else if s < 50 then "Weak"
  else if s < 75 then "Medium"
  else "Strong"

let html s =
  Tyxml.Html.svg
    ~a:[ a_class [ ("d-WifiSignal d-WifiSignal--" ^ (modifier s)) ]
    ; a_width (24., None)
    ; a_height (24., None)
    ; a_viewBox (0., 0., 24., 24.)
    ; a_fill `None
    ; a_stroke `CurrentColor
    ; a_stroke_width (2., None)
    ; a_stroke_linecap `Round
    ; a_stroke_linejoin `Round
    ]
    [ path
        ~a:[ a_class [ "d-WifiSignal__Wave--Outer" ]
        ; a_d "M1.42 9a16 16 0 0 1 21.16 0"
        ]
        []
    ; path
        ~a:[ a_class [ "d-WifiSignal__Wave--Middle" ]
        ; a_d "M5 12.55a11 11 0 0 1 14.08 0"
        ]
        []
    ; path
        ~a:[ a_class [ "d-WifiSignal__Wave--Inner" ]
        ; a_d "M8.53 16.11a6 6 0 0 1 6.95 0"
        ]
        []
    ; line
        ~a:[ a_class [ "d-WifiSignal__Base" ]
        ; a_x1 (12., None)
        ; a_y1 (20., None)
        ; a_x2 (12., None)
        ; a_y2 (20., None)
        ]
        []
    ]
