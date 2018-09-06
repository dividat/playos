# This module defines a small NixOS configuration.  It does not
# contain any graphical stuff.

{ config, lib, ... }:

with lib;

{
  fileSystems."/".device = "/dev/disk/by-label/nixos";
  boot.loader.grub.device = "/dev/sda";

  environment.noXlibs = mkDefault true;

  # This isn't perfect, but let's expect the user specifies an UTF-8 defaultLocale
  #i18n.supportedLocales = [ (config.i18n.defaultLocale + "/UTF-8") ];

  #documentation.enable = mkDefault false;
  services.nixosManual.enable = mkDefault false;

  sound.enable = mkDefault false;
}
