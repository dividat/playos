# This module defines a small NixOS configuration.  It does not
# contain any graphical stuff.

{ config, pkgs, lib, version,... }:

with lib;

{

  # Force use of already overlayed nixpkgs in modules
  nixpkgs.pkgs = pkgs;

  imports = [
    ../modules/system-partition.nix

    ./rauc

    # Play Kiosk and Driver
    # ./play-kiosk.nix

    # Development helpers
    ./development.nix


  ];


  fileSystems = {
    "/" = {
      # Create a tmpfs as root
      fsType = "tmpfs";
      options = [ "mode=0755" ];
    };
    "/boot" = {
      device = "/dev/disk/by-label/ESP";
    };

    # Persistent user data
    "/data" = {
      device = "/dev/disk/by-label/data";
      # mount during stage-1, so that directories can be initialized (see `boot.postBootCommands`) before systemd bind mounts.
      neededForBoot = true;
    };

    # NetworkManager system-configurations
    "/etc/NetworkManager/system-connections" = {
      device = "/data/NetworkManager/system-connections";
      options = [ "bind" ];
    };

  };

  boot.postBootCommands = ''
    # Make sure directories on /data partition exist
    echo "ensuring directories exist on /data partition..."
    mkdir -p /data/NetworkManager/system-connections/
    chmod -R 700 /data/NetworkManager/system-connections
  '';

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
             /       |                Dividat PlayOS (${version})
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

  # disable installation of bootloader
  boot.loader.grub.enable = false;

  environment.systemPackages = with pkgs; [];

  environment.noXlibs = true;

  # Enable non-free firmware
  hardware.enableRedistributableFirmware = true;

  networking.networkmanager.enable = true;
  networking.hostName = "playos";

}
