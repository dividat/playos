open Info
open Tyxml.Html

let remote_maintenance_form action button_label =
  form
    ~a:
      [ a_action ("/remote-maintenance/" ^ action)
      ; a_method `Post
      ; a_class [ "d-Info__RemoteMaintenanceForm" ]
      ; Unsafe.string_attrib "is" "disable-after-submit"
      ]
    [ input
        ~a:
          [ a_input_type `Submit; a_class [ "d-Button" ]; a_value button_label ]
        ()
    ]

let remote_maintenance address =
  match address with
  | Some address ->
      [ span
          ~a:[ a_class [ "d-Info__RemoteMaintenanceAddress" ] ]
          [ txt address ]
      ; remote_maintenance_form "disable" "Disable"
      ]
  | None ->
      [ div
          ~a:[ a_class [ "d-Note" ] ]
          [ txt
              "Enabling remote maintenance allows Dividat to access this \
               computer at a distance. For this purpose the computer's public \
               IP address is shared with ZeroTier, a US-based company \
               providing an overlay network."
          ]
      ; remote_maintenance_form "enable" "Enable"
      ]

let html server_info =
  Page.html ~current_page:Page.Info
    ~header:(Page.header_title ~icon:Icon.info [ txt "Information" ])
    (div
       [ Definition.list
           [ Definition.term [ txt "Version" ]
           ; Definition.description [ txt server_info.version ]
           ; Definition.term [ txt "Update URL" ]
           ; Definition.description [ txt server_info.update_url ]
           ; Definition.term [ txt "Kiosk URL" ]
           ; Definition.description [ txt server_info.kiosk_url ]
           ; Definition.term [ txt "Machine ID" ]
           ; Definition.description [ txt server_info.machine_id ]
           ; Definition.term [ txt "Local time" ]
           ; Definition.description [ txt server_info.local_time ]
           ; Definition.term [ txt "Remote maintenance" ]
           ; Definition.description
               (remote_maintenance server_info.zerotier_address)
           ]
       ]
    )
