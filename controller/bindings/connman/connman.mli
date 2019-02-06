module Technology : sig
  type t = {
    _proxy: OBus_proxy.t Sexplib.Conv.sexp_opaque
  ; name : string
  ; type' : string
  } [@@deriving sexp]

  val scan : t -> unit Lwt.t
end

module Agent : sig
  type input =
    | None
    | Passphrase of string
end

module Service : sig
  type type' =
    | Wifi
    | Ethernet
  [@@deriving sexp]

  type state =
    | Idle
    | Failure
    | Association
    | Configuration
    | Ready
    | Disconnect
    | Online
  [@@deriving sexp]

  type t = {
    _proxy : OBus_proxy.t Sexplib.Conv.sexp_opaque
  ; _manager: OBus_proxy.t Sexplib.Conv.sexp_opaque
  ; id : string
  ; name : string
  ; type' : type'
  ; state : state
  ; strength : int option
  ; favorite : bool
  ; autoconnect : bool
  }
  [@@deriving sexp]

  val connect : ?input:Agent.input -> t -> unit Lwt.t

  val disconnect : t -> unit Lwt.t

  val remove : t -> unit Lwt.t

end

module Manager : sig
  type t = OBus_proxy.t

  val connect : unit -> t Lwt.t

  val get_technologies : t -> Technology.t list Lwt.t

  val get_services : t -> Service.t list Lwt.t

end
