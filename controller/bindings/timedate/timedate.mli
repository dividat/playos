type t = OBus_peer.Private.t

(** [daemon ()] returns the peer object for the timedate1 service/daemon *)
val daemon : unit -> t Lwt.t

(** [get_available_timezones daemon] returns the available timezones in the system *)
val get_available_timezones : t -> (string list) Lwt.t

(** [get_current_time daemon] returns the current formatted timestamp *)
val get_current_time : t -> string Lwt.t

(** [get_active_timezone daemon] returns the currently active timezone *)
val get_active_timezone : t -> (string option) Lwt.t

(** [get_configured_timezone daemon] returns the configured timezone *)
val get_configured_timezone : unit -> (string option) Lwt.t

(** [set_timezone daemon timezone] sets the timezone *)
val set_timezone : string -> bool Lwt.t

module Org_freedesktop_timedate1 : sig
  val timezone : OBus_proxy.t -> (string, [ `readable ]) OBus_property.t
  val local_rtc : OBus_proxy.t -> (bool, [ `readable ]) OBus_property.t
  val can_ntp : OBus_proxy.t -> (bool, [ `readable ]) OBus_property.t
  val ntp : OBus_proxy.t -> (bool, [ `readable ]) OBus_property.t
  val ntpsynchronized : OBus_proxy.t -> (bool, [ `readable ]) OBus_property.t
  val time_usec : OBus_proxy.t -> (int64, [ `readable ]) OBus_property.t
  val rtctime_usec : OBus_proxy.t -> (int64, [ `readable ]) OBus_property.t
  val set_time : OBus_proxy.t -> int64 -> bool -> bool -> unit Lwt.t
  val set_timezone : OBus_proxy.t -> string -> bool -> unit Lwt.t
  val set_local_rtc : OBus_proxy.t -> bool -> bool -> bool -> unit Lwt.t
  val set_ntp : OBus_proxy.t -> bool -> bool -> unit Lwt.t
end
