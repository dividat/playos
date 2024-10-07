type rauc_state =
    | Status of Rauc.status
    | Installing
    | Error of string

type params =
  { health: Health.state
  ; update: Update.state
  ; rauc: rauc_state
  ; booted_slot: Rauc.Slot.t
  }

val html :
  params
  -> [> Html_types.html ] Tyxml.Html.elt
