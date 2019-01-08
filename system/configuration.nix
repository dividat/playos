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

  networking.hostName = "playos";

  # Use NetworkManager
  networking.networkmanager.enable = true;

  # Use dhcpcd which supports fallback to link-local addressing.
  # NetworkManager per default does not fall back to link-local addressing (IPv4LL) [1].
  # [1] https://mail.gnome.org/archives/networkmanager-list/2009-April/msg00073.html
  networking.networkmanager.dhcp = "dhcpcd";

  # TODO: remove debug
  environment.etc."dhcpcd.conf".text = ''
    debug
  '';

  # Use Google Public DNS as fallback
  networking.networkmanager.appendNameservers = [ "8.8.8.8" "8.8.4.4" ];

}
