# Build NixOS system
{ config, lib, pkgs
, version, install-playos
}:
let
  nixos = pkgs.importFromNixos "";

  configuration = (import ./configuration.nix) {
    # TODO: what is the config that goes in there?
    inherit config pkgs lib install-playos version;
  };

in
(nixos {
  inherit configuration;
  system = "x86_64-linux";
}).config.system.build.isoImage

