(** ConnMan Technology API *)
module Technology : sig

  (** Type of technology. *)
  type type' =
    | Wifi
    | Ethernet
    | Bluetooth
    | P2P
  [@@deriving sexp]

  (** ConnMan Technology.

      Note that not all properties are encoded.
  *)
  type t = {
    _proxy: OBus_proxy.t Sexplib.Conv.sexp_opaque
  ; name : string
  ; type' : type'
  ; powered : bool
  ; connected : bool
  } [@@deriving sexp]

  (** Enable a technology *)
  val enable : t -> unit Lwt.t

  (** Disable a technology *)
  val disable : t -> unit Lwt.t

  (** Trigger a scan for technology [t].*)
  val scan : t -> unit Lwt.t
end

(** ConnMan Agent API

    A D-Bus ConnMan agent is implemented by this module to provide inputs for secured networks. The agent is not started manually, but is automatically created by the [Service.connect] function.
*)
module Agent : sig

  (** Input that the agent may provide to connect to a network.

      Note that not all possible inputs are supported and thus connecting to some networks is not possible (e.g. WPS). See the ConnMan Agent API documentation for more information.
  *)
  type input =
    | None (** No input *)
    | Passphrase of string (** The passphrase for authentication. For example a WEP key, a PSK passphrase or a passphrase for EAP authentication methods.*)
  [@@deriving sexp]
end

(** ConnMan Service API*)
module Service : sig

	(** The service state information. *)
  type state =
    | Idle
    | Failure
    | Association
    | Configuration
    | Ready
    | Disconnect
    | Online
  [@@deriving sexp]

  (** IPv4 properties *)
  module IPv4 : sig
    type t = {
      method' : string
    ; address : string
    ; netmask : string
    ; gateway : string
    }
    [@@deriving sexp]
  end

  (** IPv6 properties *)
  module IPv6 : sig
    type t = {
      method' : string
    ; address : string
    ; prefix_length: int
    ; gateway : string
    ; privacy : string
    }
    [@@deriving sexp]
  end

  (** Ethernet properties *)
  module Ethernet : sig
    type t = {
      method' : string
    ; interface : string
    ; address : string
    ; mtu : int
    }
    [@@deriving sexp]
  end

  (** ConnMan Service

      Note that not all properties are encoded.
  *)
  type t = {
    _proxy : OBus_proxy.t Sexplib.Conv.sexp_opaque
  ; _manager: OBus_proxy.t Sexplib.Conv.sexp_opaque
  ; id : string
  ; name : string
  ; type' : Technology.type'
  ; state : state
  ; strength : int option
  ; favorite : bool
  ; autoconnect : bool
  ; ipv4 : IPv4.t option
  ; ipv6 : IPv6.t option
  ; ethernet : Ethernet.t
  }
  [@@deriving sexp]

  (** Helper to decide if service is connected *)
  val is_connected : t -> bool

  (** Encode service as JSON.

      Note that this is not a direct mapping, but offers limited fields usable for UI. For more exact representation use S-Exp.
  *)
  val to_json : t -> Ezjsonm.t

  val connect : ?input:Agent.input -> t -> unit Lwt.t

  (** Disconnect service. *)
  val disconnect : t -> unit Lwt.t

  (** A successfully connected service with favorite=true
			can be removed this way. If it is connected, it will
			be automatically disconnected first.*)
  val remove : t -> unit Lwt.t

end

(** ConnMan Manager API *)
module Manager : sig
  type t = OBus_proxy.t

  (** Connect to ConnMan *)
  val connect : unit -> t Lwt.t

  (** Returns a list of technologies *)
  val get_technologies : t -> Technology.t list Lwt.t

  (** Returns a list of services *)
  val get_services : t -> Service.t list Lwt.t

  (** Returns a signal carrying services.

      This uses the ConnMan ServiceChanged Signal but returns complete services instead of only changes.*)
  val get_services_signal : t -> Service.t list Lwt_react.S.t Lwt.t

end
