# Remove nix tools from system.
#
# PlayOS is built with nix, but is not managed with nix from within the installation.
{config, pkgs, lib, ... }:
{
  nix.enable = lib.mkForce false;
  nix.settings.allowed-users = lib.mkForce [];
  # Useless when there is no way to install
  programs.command-not-found.enable = lib.mkForce false;
  # We don't need a helper to explain failed ELF loads
  environment.stub-ld.enable = lib.mkForce false;

  # disable inaccessible documentation
  documentation = {
    enable = false;
    doc.enable = false;
    info.enable = false;
    man.enable = false;
    nixos.enable = false;
  };
}
