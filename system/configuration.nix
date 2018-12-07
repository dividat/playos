# This module defines a small NixOS configuration.  It does not
# contain any graphical stuff.

{ config, pkgs, lib, version,... }:

with lib;

{

  # Force use of already overlayed nixpkgs in modules
  nixpkgs.pkgs = pkgs;

  imports = [
    ./modules/update-mechanism

    # Play Kiosk and Driver
    # ./modules/play

    # Development helpers
    ./modules/development
  ];


  fileSystems = {
    "/" = {
      # Create a tmpfs as root
      fsType = "tmpfs";
      options = [ "mode=0755" ];
    };
    "/mnt/system" = {
      # Mount root read-only at /system
      device = "/dev/root";
      options = [ "ro" ];
      neededForBoot = true;
    };
    "/nix/store" = {
      # Bind mount nix store
      device = "/mnt/system/nix/store";
      options = [ "bind" ];
    };
    "/boot" = {
      device = "/dev/disk/by-label/ESP";
    };
    "/data" = {
      device = "/dev/disk/by-label/data";
    };
  };

  boot.initrd.postMountCommands = ''
    # Link the stage-2 init to /, so that stage-1 can find it
    cd $targetRoot
    ln -s mnt/system/init init
    cd /
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

}
