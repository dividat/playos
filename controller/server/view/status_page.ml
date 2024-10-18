open Tyxml.Html
open Sexplib.Std

type rauc_state =
    | Status of Rauc.status
    | Installing
    | Error of string
    [@@deriving sexp]

type params =
  { health: Health.state
  ; update: Update.state
  ; rauc: rauc_state
  ; booted_slot: Rauc.Slot.t
  }

let definition term description =
  [ Definition.term [ txt term ]
  ; Definition.description [ pre ~a: [ a_class [ "d-Preformatted" ] ]  [ txt description ] ]
  ]

let health_fmt s = s |> Health.sexp_of_state |> Sexplib.Sexp.to_string_hum
let update_fmt s = s |> Update.sexp_of_state |> Sexplib.Sexp.to_string_hum
let rauc_fmt s = s |> sexp_of_rauc_state |> Sexplib.Sexp.to_string_hum
let slot_fmt = Rauc.Slot.string_of_t

let opt_elem opt = Option.value ~default:[] @@ Option.map (fun e -> [e]) opt

let action_form ?confirm_msg action button_label =
  form
    ~a:[ a_action action
    ; a_method `Post
    ; a_class [ "d-Status__ActionForm" ]
    ]
    [ input
        ~a:([ a_input_type `Submit
        ; a_class [ "d-Button" ]
        ; a_value button_label
        ] @ (opt_elem (Option.map (fun (m) ->
                a_onclick (Format.sprintf "return confirm('%s');" m))
            confirm_msg)))
        ()
    ]

let note body = div
  ~a:[ a_class [ "d-Note" ] ]
  [ txt body  ]

let reboot_call =
      [ note "There is a new system update installed, reboot PlayOS to enable it."
      ; action_form "/system/reboot" "Reboot into updated version"
      ]

let switch_to_newer_system_call target_slot =
      [ note "This machine has an out of date PlayOS version selected as the
              default. You can switch to the new version (requires a reboot)."
      ; action_form
            ("/system/switch/" ^ (slot_fmt target_slot))
            "Switch to newer version and reboot"
      ]

let switch_to_older_system_call target_slot =
      [ note "You are running the latest version of PlayOS, but you can still
              switch back to the older version (requires a reboot)."
      ; action_form
            ("/system/switch/" ^ (slot_fmt target_slot))
            "Switch to older version and reboot"
      ]

let reinstall_call target_slot  =
      [ note "The PlayOS installation appears to be faulty, manual system
              reinsallation is recommended. Please contact support. You can
              attempt to switch to another system slot (requires reboot)."
      ; action_form
            ("/system/switch/" ^ (slot_fmt target_slot))
            "Switch to other slot and reboot"
      ]

let factory_reset_call =
    let confirm_msg = "This will wipe all configuration and user data. Are you sure?"
    in
      [ note "WARNING: Clears all user data and reboots the machine, resulting in a
              fresh install state. Will require to manually reconfigure network,
              localization and all other settings. Users will have to re-login
              to Dividat Play."
      ; action_form ~confirm_msg ("/system/factory-reset") "Factory Reset ⚠"
      ]

let other_slot = let open Rauc.Slot in function
    | SystemA -> SystemB
    | SystemB -> SystemA

let suggested_action_of_state (update:Update.state) (rauc:rauc_state) booted_slot =
    let target_slot = other_slot booted_slot in
    match (update, rauc) with
        | (RebootRequired, _) ->
            Some (Definition.description reboot_call)
        | (OutOfDateVersionSelected, Status _) ->
            Some (Definition.description (
                switch_to_newer_system_call target_slot
            ))
        | (UpToDate _, Status _) ->
            Some (Definition.description (
                switch_to_older_system_call target_slot
            ))
        | (ReinstallRequired, _) ->
            Some (Definition.description (
                reinstall_call target_slot
            ))
        | _ ->
            None

let html { health; booted_slot; update; rauc } =
let opt_action = suggested_action_of_state update rauc booted_slot
in
  Page.html
    ~current_page:Page.SystemStatus
    ~header:(Page.header_title
      ~icon:Icon.screen
      [ txt "System Status"
      ])
    (Definition.list
      (definition "Health" (health_fmt health)
      @ definition "Update State" (update_fmt update)
      @ opt_elem opt_action
      @ definition "RAUC" (rauc_fmt rauc)
      @ [
          Definition.term [txt "Factory reset" ]
        ; Definition.description factory_reset_call
        ]
    ))
