# Application-specific trimming.
#
# The main goal is to shed unnecessary weight from ISOs and update bundles,
# hardening is a side-effect.
#
# Partly inspired by the NixOS profiles `minimal.nix` and `headless.nix`.
{config, pkgs, lib, ... }:
{
  # Useful as a "regression test" to identify packages that slipped into
  # the closure before and should not do so again.
  system.forbiddenDependenciesRegexes = [
    "adwaita"
    "xterm"
  ];

  # Override defaults from nixpkgs that would pull in unnecessary GUI deps
  services.xserver.displayManager.lightdm.greeters.gtk.enable = lib.mkForce false;
  services.xserver.excludePackages = [ pkgs.xterm ];
  gtk.iconCache.enable = lib.mkForce false;

  # We assume a monoapp and don't need desktop manager mediation
  xdg = {
    autostart.enable = lib.mkForce false;
    icons.enable = lib.mkForce false;
    mime.enable = lib.mkForce false;
    sounds.enable = lib.mkForce false;
    portal = {
      enable = lib.mkForce false;
      extraPortals = lib.mkForce [];
    };
  };

  # Only include a single fallback font, assume kiosk app brings fonts
  fonts.enableDefaultPackages = false;
  fonts.fontconfig.enable = lib.mkForce false;
  fonts.packages = lib.mkForce [ pkgs.fira ];
}
