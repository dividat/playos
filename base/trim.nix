# Trim down the base system.
#
# The main goal is to shed unnecessary weight from ISOs and update bundles,
# hardening is a side-effect.
#
# For intentional hardening, see `hardening.nix`.
#
# Partly inspired by the NixOS profiles `minimal.nix` and `headless.nix`.
{config, pkgs, lib, ... }:
{
  # disable inaccessible documentation
  documentation = {
    enable = false;
    doc.enable = false;
    info.enable = false;
    man.enable = false;
    nixos.enable = false;
  };

  # Override a default from nixpkgs that would pull in Adwaita theme needlessly
  services.xserver.displayManager.lightdm.greeters.gtk.enable = lib.mkDefault false;
}
