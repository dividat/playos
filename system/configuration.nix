# NixOS configuration file

{ config, pkgs, lib, ... }:

with lib;

{

  imports = [
    # Play Kiosk and Driver
    ./play-kiosk.nix

    # Remote management
    ./remote-management.nix

    # Localization
    ./localization.nix

    # Update Machinery
    ./rauc

    # Networking
    ./networking
  ];

  systemPartition = {
    enable = true;
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

}
