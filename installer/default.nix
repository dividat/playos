# Build NixOS system
{ config, lib, pkgs
, version, fullProductName, greeting, install-playos
}:
let
  nixos = pkgs.importFromNixos "";

  configuration = (import ./configuration.nix) {
    inherit config pkgs lib install-playos version fullProductName greeting;
  };

in
(nixos {
  inherit configuration;
  system = "x86_64-linux";
}).config.system.build.isoImage

