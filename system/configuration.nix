# NixOS configuration file

{ config, pkgs, lib, ... }:

with lib;

{

  imports = [
    ./rauc

    # Play Kiosk and Driver
    # ./play-kiosk.nix

    # Development helpers
    ./development.nix
  ];

  systemPartition = {
    device = "/dev/root";
  };

  volatileRoot = {
    persistentDataPartition.device = "/dev/disk/by-label/data";
    persistentFolders = {
      "/etc/NetworkManager/system-connections" = {
        mode = "0700";
        user = "root";
        group = "root";
      };
    };
  };

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

  networking.networkmanager.enable = true;
  networking.hostName = "playos";

}
