(** Initialize Network connectivity *)
val init
  : connman : Connman.Manager.t
  -> (unit,exn) Lwt_result.t

module Interface : sig
  (** Network interface *)
  type t =
    { index: int
    ; name: string
    ; address: string
    ; link_type: string
    }
  [@@deriving sexp, yojson]

  val to_json : t -> Ezjsonm.value

  (** Get all available interfaces.

      This uses the Linux `ip` utility.
  *)
  val get_all : unit -> t list Lwt.t

end
