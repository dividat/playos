# Build NixOS system
{config, lib, pkgs, nixos, version}:
let
  configuration = (import ./configuration.nix) { inherit config pkgs lib version; };
in
  (nixos {
    inherit configuration;
    system = "x86_64-linux";
  }).config.system.build.toplevel

