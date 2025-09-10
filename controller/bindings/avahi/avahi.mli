module Service : sig
  type t =
    { service_name : string
    ; service_type : string
    ; interface : string
    }

  val get_service_type : ?timeout_seconds:float -> string -> t list Lwt.t

  (* Exposed for unit tests *)
  val unescape_label : string -> string option
end
