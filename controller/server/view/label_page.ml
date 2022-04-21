open Label_printer
open Tyxml.Html

let default_label_printer_url = "http://192.168.0.5:3000/play-computer"

let html { machine_id; mac_1; mac_2 } =
  Page.html 
    ~header:(Page.header_title [ txt "Print Label" ])
    (div
      [ Definition.list
          [ Definition.term [ txt "Machine ID" ]
          ; Definition.description [ txt machine_id ]

          ; Definition.term [ txt "MAC (1)" ]
          ; Definition.description [ txt mac_1 ]

          ; Definition.term [ txt "MAC (2)" ]
          ; Definition.description [ txt mac_2 ]
          ]

      ; form
          ~a:[ a_action "/label/print"
          ; a_method `Post
          ; Unsafe.string_attrib "is" "disable-after-submit"
          ]
          [ Definition.list
              [ Definition.term [ txt "Label Printer URL" ]
              ; Definition.description
                  [ input
                      ~a:[ a_input_type `Text
                      ; a_class [ "d-Input" ]
                      ; a_size 40
                      ; a_value default_label_printer_url
                      ; a_name "label_printer_url"
                      ]
                      ()
                  ]
              ; Definition.term [ txt "How many labels?" ]
              ; Definition.description
                  [ input
                      ~a:[ a_input_type `Number
                      ; a_class [ "d-Input" ]
                      ; a_input_min (`Number 1)
                      ; a_input_max (`Number 5)
                      ; a_value "2"
                      ; a_name "count"
                      ]
                      ()
                  ]
              ]
          ; input
              ~a:[ a_input_type `Submit
              ; a_class [ "d-Button" ]
              ; a_value "Print"
              ]
              ()
          ]
      ])
