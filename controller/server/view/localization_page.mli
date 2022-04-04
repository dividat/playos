type params =
  { timezone_groups: (string * ((string * string) list)) list
  ; current_timezone: string option
  ; langs: (string * string) list
  ; current_lang: string option
  ; keymaps: (string * string) list
  ; current_keymap: string option
  ; opt_in_scaling : bool
  }

val html :
  params
  -> [> Html_types.html ] Tyxml.Html.elt
