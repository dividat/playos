# This is the toplevel module for all PlayOS related functionalities.

# Things that are injected into the system
{version, pkgs}:


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
  };

  config = {

    # Use overlayed pkgs
    nixpkgs.pkgs = pkgs;

    # disable installation of bootloader
    boot.loader.grub.enable = false;

    playos = {
      inherit version;
    };
  };
}
