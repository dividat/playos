# Build NixOS system
{ config, lib, pkgs
, version, safeProductName, fullProductName, greeting, install-playos
}:
let
  nixos = pkgs.importFromNixos "";

  configuration = (import ./configuration.nix) {
    inherit config pkgs lib install-playos version safeProductName fullProductName greeting;
  };

in
(nixos {
  inherit configuration;
  system = "x86_64-linux";
}).config.system.build.isoImage

