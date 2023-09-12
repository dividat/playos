# PlayOS Controller

Controller for PlayOS systems.

## Overview

PlayOS controller is an OCaml application that manages various system tasks for the PlayOS system (such as updating, health monitoring, offering a unified interface for configuration). Consult the PlayOS Architecture documentation for more information.

## Folders

- `bindings/`: bindings to various things
- `gui/`: static gui assets
- `nix/`: nix stuff
- `server/`: main application code
- `bin/`: binaries to start a dev server

## Prerequisites
Since PlayOS uses `Connman` for managing networks, it must be configured on your system.
The following suggestion for setting up `Connman` assumes you are on NixOS.
Replace your NetworkManager config with the following (remember to fill in `<your-host-name>`):

```nix
{ pkgs, config, ... }:
{
  networking = {
    hostName = <your-hostname>;
    extraHosts = "127.0.0.1 <your-hostname>";
    wireless = {
      enable = true;
      # Issue 1: Add a dummy network to make sure wpa_supplicant.conf
      # is created (see https://github.com/NixOS/nixpkgs/issues/23196)
      networks."12345-i-do-not-exist" = {
        extraConfig = ''
          disabled=1
        '';
      };

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
    # Legacy networkmanager config
    networkmanager = {
      enable = false;
      # Cloudflare DNS; advertised as using good privacy practices (https://1.1.1.1/)
      insertNameservers = [ "1.1.1.1" "1.0.0.1" ];
      packages = [ pkgs.networkmanagerapplet ];
    };
  };

  # Issue 1: Make sure connman starts after wpa_supplicant
  systemd.services."connman".after = [ "wpa_supplicant.service" ];
  # Issue 2: Restart wpa_supplicant (and thereby connman) after rfkill unblock of wlan
  #          This addresses the problem of wpa_supplicant with connman not seeing any
  #          networks if wlan was initially soft blocked. (https://01.org/jira/browse/CM-670)
  services.udev.packages = [ pkgs.rfkill_udev ];
  environment.etc."rfkill.hook".source = pkgs.writeShellScript "rfkill.hook" ''
    # States: 1 - normal, 0 - soft-blocked, 2 - hardware-blocked
    if [ "$RFKILL_STATE" == 1 ]; then
      # Wait an instant. Immediate restart gets wpa_supplicant stuck in the same way.
      sleep 5

      ${config.systemd.package}/bin/systemctl try-restart wpa_supplicant.service
    fi
  '';

  services.connman = {
    enable = true;
    networkInterfaceBlacklist = [
      "vboxnet"
      "zt"
      "vmnet"
      "vboxnet"
      "virbr"
      "ifb"
      "docker"
      "veth"
      "eth"
      "wlan"
    ];
    extraConfig = ''
      [General]
      AllowHostnameUpdates=false
      AllowDomainnameUpdates=false
      EnableOnlineCheck=true

      # Ethernet will generally be used for internet, use as default route
      PreferredTechnologies=ethernet,wifi

      # Allow simultaneous connection to ethernet and wifi
      SingleConnectedTechnology=false
    '';
  };
}
```

## Quick start


Run `nix-shell` to create a suitable development environment.

Then, start the the controller with `bin/dev-server`.

## Code style

- Author CSS according to the [BEM methodology](http://getbem.com/) in the format `d-Block__Element--Modifier`.

## See also

Many ideas have been taken from the [logarion](https://cgit.orbitalfox.eu/logarion/) project.
