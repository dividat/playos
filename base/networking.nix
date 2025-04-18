{config, pkgs, lib, hostName, ... }:
with builtins;
with lib;
let
    wifiIfs = config.networking.wireless.interfaces;
    # see nixos wpa_supplicant.nix module
    wpaSupplicantServices =
      if wifiIfs == [] then [ "wpa_supplicant.service" ]
      else map (i: "wpa_supplicant-${i}.service") wifiIfs;
in
{
  # Enable non-free firmware
  hardware.enableRedistributableFirmware = true;

  # Tools for basic network troubleshooting
  # We purposefully omit more powerful tools such as tcpdump and nmap, which
  # sysadmins may not want to be present in their networks.
  environment.systemPackages = with pkgs; [
    ethtool # for inspecting Ethernet interface status
    bind.dnsutils # dig and nslookup for DNS
    traceroute # for connectivity
  ];

  # Set up networking with ConnMan
  # We need to work around various issues in the interplay of connman and
  # wpa_supplicant for this to work.
  services.connman = {
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

  networking = {
    hostName = hostName;

    wireless = {
      enable = true;

      # Stabilize WIFI connection scanning by keeping any scanned WIFI for at
      # least 1 minute. This intends to fix “Service not found” error when
      # connecting to a network by id.
      extraConfig = ''
        # BSS expiration age in seconds. A BSS will be removed from the local cache
        # if it is not in use and has not been seen for this time. Default is 180.
        bss_expiration_age=60

        # BSS expiration after number of scans. A BSS will be removed from the local
        # cache if it is not seen in this number of scans.
        # Default is 2.
        bss_expiration_scan_count=1000
      '';
    };
  };
  # Issue 1: Make sure connman starts after wpa_supplicant
  systemd.services."connman".after = wpaSupplicantServices;
  # Issue 2: Restart wpa_supplicant (and thereby connman) after rfkill unblock of wlan
  #          This addresses the problem of wpa_supplicant with connman not seeing any
  #          networks if wlan was initially soft blocked. (https://web.archive.org/web/20191211094135/https://01.org/jira/browse/CM-670)
  services.udev.packages = [ pkgs.rfkill_udev ];
  environment.etc."rfkill.hook".source = pkgs.writeShellScript "rfkill.hook" ''
    # States: 1 - normal, 0 - soft-blocked, 2 - hardware-blocked
    if [ "$RFKILL_STATE" == 1 ]; then
      # Wait an instant. Immediate restart gets wpa_supplicant stuck in the same way.
      sleep 5

      ${config.systemd.package}/bin/systemctl try-restart \
        ${toString wpaSupplicantServices}
    fi
  '';

  # Make connman folder persistent
  playos.storage.persistentFolders."/var/lib/connman" = {
    mode = "0700";
    user = "root";
    group = "root";
  };
}
