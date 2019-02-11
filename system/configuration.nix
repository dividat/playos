# NixOS configuration file

{ config, pkgs, lib, ... }:

with lib;

{

  imports = [
    # Play Kiosk and Driver
    ./play-kiosk.nix

    # Remote management
    ./remote-management.nix

    # Update Machinery
    ./rauc

    # Development helpers
    ./development.nix
  ];

  systemPartition = {
    device = "/dev/root";
  };

  volatileRoot.persistentDataPartition.device = "/dev/disk/by-label/data";


  fileSystems = {
    "/boot" = {
      device = "/dev/disk/by-label/ESP";
    };
  };


  # Codename Dancing Bear
  services.mingetty.greetingLine =
  ''
                           _,-'^\
                       _,-'   ,\ )
                   ,,-'     ,'  d'
    ,,,           J_ \    ,'
   `\ /     __ ,-'  \ \ ,'
   / /  _,-'  '      \ \
  / |,-'             /  }
  (                 ,'  /
  '-,________         /
             \       /
              |      |
             /       |                Dividat PlayOS (${config.playos.version})
            /        |
           /  /~\   (\/)
          {  /   \     }
          | |     |   =|
          / |      ~\  |
          J \,       (_o
           '"
  '';

  services.mingetty.helpLine = "";

  # disable installation of documentation
	documentation.enable = false;

  environment.systemPackages = with pkgs; [];

  # Enable non-free firmware
  hardware.enableRedistributableFirmware = true;

  # Use ConnMan
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

        # Disable calling home
        EnableOnlineCheck=false
      '';
    };
    # enable wpa_supplicant
    wireless = {
      enable = true;
      # Add a dummy network to make sure that wpa_supplicant.conf is created (see https://github.com/NixOS/nixpkgs/issues/23196)
      networks."12345-i-do-not-exist"= {};
    };
  };

  # Make connman folder persistent
  volatileRoot.persistentFolders."/var/lib/connman" = {
    mode = "0700";
    user = "root";
    group = "root";
  };

  # Start controller
  systemd.services.playos-controller = {
    description = "PlayOS Controller";
    serviceConfig = {
      ExecStart = "${pkgs.playos-controller}/bin/playos-controller ${config.playos.updateUrl}";
      User = "root";
      RestartSec = "10s";
      Restart = "always";
    };
    wantedBy = [ "multi-user.target" ];
  };

}
