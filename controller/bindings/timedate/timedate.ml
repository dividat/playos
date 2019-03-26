open Lwt
open Timedate_interfaces

let log_src = Logs.Src.create "timedate"

type t = OBus_peer.Private.t

(* Timezone Configuration *)

let get_configured_timezone () =
  Util.read_from_file log_src "/var/lib/gui-localization/timezone"

let set_timezone timezone =
  Util.write_to_file log_src "/var/lib/gui-localization/timezone" timezone

(* Active Timezone *)

let daemon () =
  let%lwt system_bus = OBus_bus.system () in
  let peer = OBus_peer.make system_bus "org.freedesktop.timedate1" in
  return peer

let proxy daemon =
  OBus_proxy.make daemon ["org"; "freedesktop"; "timedate1"]

let get_active_timezone daemon =
  let%lwt raw_tz =
    OBus_property.make
      Org_freedesktop_timedate1.p_Timezone
      (proxy daemon)
    |> OBus_property.get
  in
  if String.length raw_tz == 0 then
    None |> return
  else
    Some raw_tz |> return

let get_current_time daemon =
  Lwt_process.pread ("", [|"date"; "+%Y-%m-%d %H:%M UTC%z"|])

let get_available_timezones daemon =
  (* Newer versions of systemd add a DBus property for this. *)
  Lwt_process.pread_lines ("", [|"timedatectl"; "list-timezones"|])
  |> Lwt_stream.to_list


(* Auto generated with obus-gen-client *)
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
end = struct
  open Org_freedesktop_timedate1


  let timezone proxy =
    OBus_property.make p_Timezone proxy

  let local_rtc proxy =
    OBus_property.make p_LocalRTC proxy

  let can_ntp proxy =
    OBus_property.make p_CanNTP proxy

  let ntp proxy =
    OBus_property.make p_NTP proxy

  let ntpsynchronized proxy =
    OBus_property.make p_NTPSynchronized proxy

  let time_usec proxy =
    OBus_property.make p_TimeUSec proxy

  let rtctime_usec proxy =
    OBus_property.make p_RTCTimeUSec proxy

  let set_time proxy x1 x2 x3 =
    OBus_method.call m_SetTime proxy (x1, x2, x3)

  let set_timezone proxy x1 x2 =
    OBus_method.call m_SetTimezone proxy (x1, x2)

  let set_local_rtc proxy x1 x2 x3 =
    OBus_method.call m_SetLocalRTC proxy (x1, x2, x3)

  let set_ntp proxy x1 x2 =
    OBus_method.call m_SetNTP proxy (x1, x2)
end
