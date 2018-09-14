# This module defines a small NixOS configuration.  It does not
# contain any graphical stuff.

{ config, pkgs, lib, ... }:

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
    defaultEnv = ./boot/barebox-default-env;
  };

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
