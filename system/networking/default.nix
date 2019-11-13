{config, pkgs, lib, ... }:
{
  # Enable non-free firmware
  hardware.enableRedistributableFirmware = true;

  # Set up networking with ConnMan
  # We need to work around various issues in the interplay of
  # connman and wpa_supplicant for this to work.
  networking = {
    hostName = "playos";
    connman = {
      enable = true;
      enableVPN = false;
      networkInterfaceBlacklist = [ "vmnet" "vboxnet" "virbr" "ifb" "ve" "zt" ];
      extraConfig = ''
        [General]
        AllowHostnameUpdates=false
        AllowDomainnameUpdates=false

        # Wifi will generally be used for internet, use as default route
        PreferredTechnologies=wifi,ethernet

        # Allow simultaneous connection to ethernet and wifi
        SingleConnectedTechnology=false

        # Enable online check to favour connected services
        EnableOnlineCheck=true
      '';
    };
    # Issue 1: Add a dummy network to make sure wpa_supplicant.conf
    # is created (see https://github.com/NixOS/nixpkgs/issues/23196)
    wireless = {
      enable = true;
      networks."12345-i-do-not-exist"= {
        extraConfig = ''
          disabled=1
        '';
      };
    };
  };
  # Issue 2: Make sure connman starts after wpa_supplicant
  systemd.services."connman".after = [ "wpa_supplicant.service" ];
  # Issue 3: Leave time for rfkill to unblock WLAN and restart wpa_supplicant & connman (https://01.org/jira/browse/CM-670)
  systemd.timers."restart-wpa" = {
    timerConfig = {
      OnBootSec = 20;
      RemainAfterElapse = false;
    };
    wantedBy = [ "timers.target" ];
  };
  systemd.services."restart-wpa" = {
    description = "Restart wpa to enable WLAN";
    serviceConfig.Type = "oneshot";
    serviceConfig.ExecStart = "/run/current-system/sw/bin/systemctl try-restart wpa_supplicant.service";
  };

  # Make connman folder persistent
  volatileRoot.persistentFolders."/var/lib/connman" = {
    mode = "0700";
    user = "root";
    group = "root";
  };
}
