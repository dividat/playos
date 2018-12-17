# Build NixOS system
{pkgs, lib, nixos, version}:
with lib;
let
  configuration = {config, ...}:
    {
      imports = [
        ./configuration.nix
        ../modules/system-partition.nix
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
    };
in
  (nixos {
    inherit configuration;
    system = "x86_64-linux";
  }).config.system.build.toplevel

