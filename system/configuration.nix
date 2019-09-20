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

  # Set a low default timeout when stopping services, to prevent the Windows 95 shutdown experience
  systemd.extraConfig = "DefaultTimeoutStopSec=15s";

  # disable installation of documentation
  documentation.enable = false;

  environment.systemPackages = with pkgs; [];

}
