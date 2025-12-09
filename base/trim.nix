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

  # System is built by but not configured with Nix once deployed
  nix.enable = false;
  programs = {
    # Useless when there is no way to install
    command-not-found.enable = lib.mkDefault false;
  };
  # We don't need a helper to explain failed ELF loads
  environment = {
    stub-ld.enable = lib.mkDefault false;
  };

  # Override a default from nixpkgs that would pull in Adwaita theme needlessly
  services.xserver.displayManager.lightdm.greeters.gtk.enable = lib.mkDefault false;
  # We assume a mono-application and don't need desktop manager mediation between apps
  xdg = {
    autostart.enable = lib.mkDefault false;
    icons.enable = lib.mkDefault false;
    mime.enable = lib.mkDefault false;
    sounds.enable = lib.mkDefault false;
    portal = {
      enable = lib.mkDefault false;
      extraPortals = lib.mkDefault [];
    };
  };

  # Only include a single fallback font
  fonts.enableDefaultPackages = false;
  fonts.fontconfig.enable = lib.mkForce false;
  fonts.packages = lib.mkForce [ pkgs.fira ];
}
