type label =
  { machine_id: string
  ; mac_1: string
  ; mac_2: string
  }
[@@deriving sexp]

val print : url : string -> label -> unit Lwt.t
