# This module defines a small NixOS configuration.  It does not
# contain any graphical stuff.

{ config, pkgs, lib, ... }:

with lib;

{

  # Force use of already overlayed nixpkgs in modules
  nixpkgs.pkgs = pkgs;

  imports = [
    ./modules/update-mechanism

    # Development helpers
    ./modules/development
  ];


  fileSystems = {
    "/" = {
      # This makes the stage 1 init use the `root` kernel argument as root device.
      device = "/dev/root";
    };

    "/boot" = {
      device = "/dev/disk/by-label/ESP";
    };

    "/data" = {
      device = "/dev/disk/by-label/data";
    };
  };

  # disable installation of documentation
	documentation.enable = false;

  # disable installation of bootloader
  boot.loader.grub.enable = false;

  environment.systemPackages = with pkgs; [];

  users.users.play = {
    isNormalUser = true;
    home = "/data/home/play";
    password = "123";
  };

}
