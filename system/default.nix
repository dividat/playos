# Build NixOS system
{config, lib, pkgs, nixos}:
let
  configuration = (import ./configuration.nix) { inherit config pkgs lib; };
in
  nixos {
    inherit configuration;
    system = "x86_64-linux";
  }

