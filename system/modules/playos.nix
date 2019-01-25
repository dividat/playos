# This is the toplevel module for all PlayOS related functionalities.

# Things that are injected into the system
{pkgs, version, keyring}:


{config, lib, ...}:
with lib;
{
  imports = [
    ./system-partition.nix
    ./volatile-root.nix
  ];

  options = {
    playos.version = mkOption {
      type = types.string;
      default = version;
    };

    playos.updateUrl = mkOption {
      type = types.string;
    };

    playos.keyring = mkOption {
      type = types.package;
    };

  };

  config = {

    # Use overlayed pkgs.
    nixpkgs.pkgs = pkgs;

    # disable installation of bootloader
    boot.loader.grub.enable = false;

    playos = {
      inherit version keyring;
    };
  };
}
