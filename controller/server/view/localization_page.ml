open Tyxml.Html

type generic_form_parameters =
  { action_url: string
  ; legend: string
  ; select_name: string
  ; has_value: bool
  ; no_value_msg: string
  }

let select_form params options =
  form
    ~a:[ a_action params.action_url
    ; a_method `Post
    ; a_class [ "d-Localization__Form" ]
    ]
    [ label
        ~a:[ a_class [ "d-Localization__Legend" ] ]
        [ txt params.legend ]
    ; select
        ~a:[ a_name params.select_name
        ; a_class [ "d-Select"; "d-Localization__Select" ]
        ; a_required ()
        ]
        ([ option
            ~a:([ a_disabled () ]
              @ (if not params.has_value then [ a_selected () ] else []))
            (txt params.no_value_msg)
        ] @ options)
    ; input
        ~a:[ a_input_type `Submit
        ; a_class [ "d-Button" ]
        ; a_value "Set"
        ]
        ()
    ]

let select_option current_id (id, name) =
  option
    ~a:(
      [ a_value id ]
      @ (if current_id = Some id then [ a_selected () ] else [])
    )
    (txt name)

let timezone_form timezone_groups current_timezone =
  let timezone_group (group_id, tzs) =
    optgroup ~label:group_id (List.map (select_option current_timezone) tzs)
  in
  select_form
    { action_url = "/localization/timezone"
    ; legend = "Timezone"
    ; select_name = "timezone"
    ; has_value = Option.is_some current_timezone
    ; no_value_msg = "Select your closest timezone…"
    }
    (List.map timezone_group timezone_groups)

let language_form langs current_lang =
  select_form
    { action_url = "/localization/lang"
    ; legend = "Language"
    ; select_name = "lang"
    ; has_value = Option.is_some current_lang
    ; no_value_msg = "Select your language…"
    }
    (List.map (select_option current_lang) langs)

let keyboard_form keymaps current_keymap =
  select_form
    { action_url = "/localization/keymap"
    ; legend = "Keyboard"
    ; select_name = "keymap"
    ; has_value = Option.is_some current_keymap
    ; no_value_msg = "Select your keyboard layout…"
    }
    (List.map (select_option current_keymap) keymaps)

type params =
  { timezone_groups: (string * ((string * string) list)) list
  ; current_timezone: string option
  ; langs: (string * string) list
  ; current_lang: string option
  ; keymaps: (string * string) list
  ; current_keymap: string option
  }

let html params =
  Page.html ~menu_focus:Page.Localization (
    div
      [ h1 ~a:[ a_class [ "d-Title" ] ] [ txt "Localization" ]
      ; timezone_form params.timezone_groups params.current_timezone
      ; language_form params.langs params.current_lang
      ; keyboard_form params.keymaps params.current_keymap
      ; aside
          ~a:[ a_class [ "d-Localization__Note" ] ]
          [ txt "Note that keyboard and language changes require a restart." ]
      ]
  )
