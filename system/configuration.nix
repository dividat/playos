# This module defines a small NixOS configuration.  It does not
# contain any graphical stuff.

{ config, pkgs, lib, ... }:

with lib;

{

  imports = [
    ./modules/barebox
  ];

  system.activationScripts.fixedSystemLocation = ''
    # Put components (stage 2 init script, kernel and initrd) required to boot
    # system at a fixed location (copy and dereference symlinks).
    cp -fL /nix/var/nix/profiles/system/init /init
    cp -fL /nix/var/nix/profiles/system/kernel /kernel
    cp -fL /nix/var/nix/profiles/system/initrd /initrd
  '';

  fileSystems."/" = {
    # This makes the stage 1 init use the `root` kernel argument as root device.
    device = "/dev/root";
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
