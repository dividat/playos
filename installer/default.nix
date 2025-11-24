# Build NixOS system
{ config, lib, pkgs
, version, safeProductName, fullProductName, greeting, install-playos
, squashfsCompressionOpts
}:
let
  nixos = pkgs.importFromNixos "";

  configuration = (import ./configuration.nix) {
    inherit config pkgs lib install-playos version safeProductName fullProductName greeting squashfsCompressionOpts;
  };

in
(nixos {
  inherit configuration;
  system = "x86_64-linux";
}).config.system.build.isoImage

