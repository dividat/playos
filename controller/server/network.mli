open Protocol_conv_jsonm

(** Initialize Network connectivity *)
val init : connman:Connman.Manager.t -> (unit, exn) Lwt_result.t

(** A partial classification of interfaces *)
type interface_kind =
  | Loopback
  | Ethernet
  | Wireless
  | Other
[@@deriving sexp]

module Interface : sig
  (** Network interface *)
  type t =
    { index : int
    ; name : string
    ; address : string
    ; link_type : string
    ; link_status : string
    }
  [@@deriving sexp, protocol ~driver:(module Jsonm)]

  val to_json : t -> Ezjsonm.value

  val get_all : unit -> t list Lwt.t

  val kind : t -> interface_kind
end
