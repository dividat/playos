open Info
open Tyxml.Html

let zerotier_form action button_label =
  form
    ~a:[ a_action ("/remote-management/" ^ action)
    ; a_method `Post
    ; a_class [ "d-Info__RemoteManagementForm" ]
    ]
    [ input
        ~a:[ a_input_type `Submit
        ; a_class [ "d-Button" ]
        ; a_value button_label
        ]
        ()
    ]

let zerotier address =
  match address with
  | Some address ->
      [ span ~a:[ a_class [ "d-Switch--On" ] ] [ txt address ]
      ; zerotier_form "disable" "Disable"
      ]
  | None ->
      [ span ~a:[ a_class [ "d-Switch--Off" ] ] [ txt "off" ]
      ; zerotier_form "enable" "Enable"
      ]

let html server_info =
  Page.html ~current_page:Page.Info (
    div
      [ h1 ~a:[ a_class [ "d-Title" ] ] [ txt "Information" ]
      ; Definition.list
          [ Definition.term [ txt "Version" ]
          ; Definition.description [ txt server_info.version ]

          ; Definition.term [ txt "Update URL" ]
          ; Definition.description [ txt server_info.update_url ]

          ; Definition.term [ txt "Kiosk URL" ]
          ; Definition.description [ txt server_info.kiosk_url ]

          ; Definition.term [ txt "Machine ID" ]
          ; Definition.description [ txt server_info.machine_id ]

          ; Definition.term [ txt "Remote management" ]
          ; Definition.description (zerotier server_info.zerotier_address)

          ; Definition.term [ txt "Local time" ]
          ; Definition.description [ txt server_info.local_time ]
          ]
      ]
  )
