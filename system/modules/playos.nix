# This is the toplevel module for all PlayOS related functionalities.

# Things that are injected into the system
{pkgs, version, cert}:


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

    playos.cert = mkOption {
      type = types.package;
    };

  };

  config = {

    # Use overlayed pkgs.
    nixpkgs.pkgs = pkgs;

    # disable installation of bootloader
    boot.loader.grub.enable = false;

    playos = {
      inherit version cert;
    };
  };
}
