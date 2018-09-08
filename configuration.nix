# This module defines a small NixOS configuration.  It does not
# contain any graphical stuff.

{ config, lib, ... }:

with lib;

{

  imports = [
    ./modules/barebox
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
  };

  boot.loader.barebox = {
    enable = true;
    defaultEnv = ./system/boot/barebox-default-env;
  };

}
