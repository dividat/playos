open Info
open Tyxml.Html

let html server_info =
  Page.html ~menu_focus:Page.Info (
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

          ; Definition.term [ txt "ZeroTier address" ]
          ; Definition.description
              [ txt (server_info.zerotier_address |> Option.value ~default:"—") ]

          ; Definition.term [ txt "Local time" ]
          ; Definition.description [ txt server_info.local_time ]
          ]
      ]
  )
