(** Global system configuration set by the build system *)
module System = struct
  (** Version, set by build system *)
  let version = "@PLAYOS_VERSION@"

  (** URL from where to get updates, set by build system *)
  let update_url = "@PLAYOS_UPDATE_URL@"

  (** URL to which kiosk is pointed *)
  let kiosk_url = "@PLAYOS_KIOSK_URL@"

  (** PlayOS bundle name prefix *)
  let bundle_name = "@PLAYOS_BUNDLE_NAME@"
end
