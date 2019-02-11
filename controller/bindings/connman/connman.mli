(** ConnMan Technology API *)
module Technology : sig

  (** ConnMan Technology.

      Note that not all properties are encoded.
  *)
  type t = {
    _proxy: OBus_proxy.t Sexplib.Conv.sexp_opaque
  ; name : string
  ; type' : string
  } [@@deriving sexp]

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

  (** The service type *)
  type type' =
    | Wifi
    | Ethernet
  [@@deriving sexp]

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

  (** ConnMan Service

      Note that not all properties are encoded.
  *)
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
