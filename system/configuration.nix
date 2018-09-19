# This module defines a small NixOS configuration.  It does not
# contain any graphical stuff.

{ config, pkgs, lib, ... }:

with lib;

{

  fileSystems."/" = {
    # This makes the stage 1 init use the `root` kernel argument as root device.
    device = "/dev/root";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
  };

  # disable installation of bootloader
  boot.loader.grub.enable = false;

  environment.systemPackages = with pkgs; [
    # Dev tools
    sudo
    dt-utils
    dtc
    vim
  ];

  users.users.dev = {
    isNormalUser = true;
    home = "/home/dev";
    extraGroups = [ "wheel" ];
    password = "123";
  };

}
