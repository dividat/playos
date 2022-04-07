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
    _proxy: (OBus_proxy.t [@sexp.opaque])
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
    ; gateway : string option
    }
    [@@deriving sexp]
  end

  (** IPv6 properties *)
  module IPv6 : sig
    type t = {
      method' : string
    ; address : string
    ; prefix_length: int
    ; gateway : string option
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

  module Proxy : sig
    type credentials =
      { user: string
      ; password: (string [@sexp.opaque])
      }
      [@@deriving sexp]

    type t =
    { host: string
    ; port: int
    ; credentials: credentials option
    }
    [@@deriving sexp]

    val validate : string -> t option
    (** [validate str] returns [t] if [str] is valid.
    
        Valid proxies:
    
          - Use the http scheme,
          - have a host and a port,
          - may have credentials.

        Example of valid proxies:

          - http://127.0.0.1:1234.
          - http://user:password@host.com:8888.*)

    val make : ?user:string -> ?password:string -> string -> int -> t
    (** Make a [t] from mandatory and optional components.  *)

    val to_uri : t -> Uri.t
    (** [to_uri t] returns a URI from [t], including escaped credentials. *)

    val pp : t -> string
    (** [to_string t] returns a URI string from [t], omitting the password. *)

  end

  (** ConnMan Service

      Note that not all properties are encoded.
  *)
  type t = {
    _proxy : (OBus_proxy.t [@sexp.opaque])
  ; _manager: (OBus_proxy.t [@sexp.opaque])
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
  ; proxy : Proxy.t option
  ; nameservers : string list
  }
  [@@deriving sexp]

  (** Helper to decide if service is connected *)
  val is_connected : t -> bool

  val set_direct_proxy : t -> unit Lwt.t

  val set_manual_proxy : t -> Proxy.t -> unit Lwt.t

  val set_manual_ipv4 : t -> address:string -> netmask:string -> gateway:string -> unit Lwt.t

  val set_dhcp_ipv4 : t -> unit Lwt.t

  val set_nameservers : t -> string list -> unit Lwt.t

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

  (** Returns the proxy of the default service, if it has one configured *)
  val get_default_proxy : t -> Service.Proxy.t option Lwt.t

end
