open Lwt
open Lwt.Infix
open Sexplib.Std
open Rauc_interfaces

let log_src = Logs.Src.create "rauc"

type t = OBus_peer.Private.t

let daemon () =
  let%lwt system_bus = OBus_bus.system () in
  let peer = OBus_peer.make system_bus "de.pengutronix.rauc" in
  return peer

let proxy daemon =
  OBus_proxy.make daemon []

module Slot =
struct
  type t =
    | SystemA
    | SystemB

  let of_string = function
    | "a" -> SystemA
    | "system.a" -> SystemA
    | "b" -> SystemB
    | "system.b" -> SystemB
    | _ -> failwith "Unexpected slot identifier."

  let string_of_t = function
    | SystemA -> "system.a"
    | SystemB -> "system.b"

  type status =
    { device : string
    ; class' : string
    ; state : string
    ; version : string
    ; sha256 : string
    ; installed_timestamp : string
    }
  [@@deriving sexp]

end


let get_booted_slot daemon =
  OBus_property.make
    De_pengutronix_rauc_Installer.p_BootSlot
    (proxy daemon)
  |> OBus_property.get
  >|= Slot.of_string

let mark_good daemon slot =
  let%lwt marked, msg = OBus_method.call
      De_pengutronix_rauc_Installer.m_Mark
      (proxy daemon)
      ("good", slot |> Slot.string_of_t)
  in
  let%lwt () = Logs_lwt.info ~src:log_src (fun m -> m "%s" msg) in
  if Slot.of_string marked == slot then
    return_unit
  else
    Lwt.fail_with "Wrong slot marked good."

type status =
  { a: Slot.status
  ; b: Slot.status
  }
[@@deriving sexp]

let json_of_status status =
  status
  |> sexp_of_status
  |> Ezjsonm.t_of_sexp

(* Helper to decode Slot.status from OBus *)
let slot_status_of_obus
    (o:(string * OBus_value.V.single) list) : Slot.status =
  let get_string key o =
    let open OBus_value.V in
    match List.assoc_opt key o with
    | Some (Basic (String s)) -> s
    | _ -> failwith (Format.sprintf "could not get string from field %s" key)
  in
  { device = get_string "device" o
  ; class' = get_string "class" o
  ; state = get_string "state" o
  ; version = get_string "bundle.version" o
  ; sha256  = get_string "sha256" o
  ; installed_timestamp = get_string "installed.timestamp" o
  }

let get_status daemon =
  let%lwt status_assoc = OBus_method.call De_pengutronix_rauc_Installer.m_GetSlotStatus
      (proxy daemon)
      ()
  in
  { a = slot_status_of_obus (List.assoc "system.a" status_assoc)
  ; b = slot_status_of_obus (List.assoc "system.b" status_assoc)
  }
  |> return


(* Auto generated with obus-gen-client *)
module De_pengutronix_rauc_Installer : sig
  val install : OBus_proxy.t -> source : string -> unit Lwt.t
  val info : OBus_proxy.t -> bundle : string -> (string * string) Lwt.t
  val mark : OBus_proxy.t -> state : string -> slot_identifier : string -> (string * string) Lwt.t
  val get_slot_status : OBus_proxy.t -> (string * (string * OBus_value.V.single) list) list Lwt.t
  val get_primary : OBus_proxy.t -> string Lwt.t
  val completed : OBus_proxy.t -> int OBus_signal.t
  val operation : OBus_proxy.t -> (string, [ `readable ]) OBus_property.t
  val last_error : OBus_proxy.t -> (string, [ `readable ]) OBus_property.t
  val progress : OBus_proxy.t -> (int * string * int, [ `readable ]) OBus_property.t
  val compatible : OBus_proxy.t -> (string, [ `readable ]) OBus_property.t
  val variant : OBus_proxy.t -> (string, [ `readable ]) OBus_property.t
  val boot_slot : OBus_proxy.t -> (string, [ `readable ]) OBus_property.t
end = struct
  open De_pengutronix_rauc_Installer


  let install proxy ~source =
    OBus_method.call m_Install proxy source

  let info proxy ~bundle =
    OBus_method.call m_Info proxy bundle

  let mark proxy ~state ~slot_identifier =
    OBus_method.call m_Mark proxy (state, slot_identifier)

  let get_slot_status proxy =
    OBus_method.call m_GetSlotStatus proxy ()

  let get_primary proxy =
    OBus_method.call m_GetPrimary proxy ()

  let completed proxy =
    OBus_signal.map
      (fun result ->
         let result = Int32.to_int result in
         result)
      (OBus_signal.make s_Completed proxy)

  let operation proxy =
    OBus_property.make p_Operation proxy

  let last_error proxy =
    OBus_property.make p_LastError proxy

  let progress proxy =
    OBus_property.map_r
      (fun x -> (fun (x1, x2, x3) -> (Int32.to_int x1, x2, Int32.to_int x3)) x)
      (OBus_property.make p_Progress proxy)

  let compatible proxy =
    OBus_property.make p_Compatible proxy

  let variant proxy =
    OBus_property.make p_Variant proxy

  let boot_slot proxy =
    OBus_property.make p_BootSlot proxy
end
