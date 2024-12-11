# Build NixOS system
{pkgs, lib, version, updateCert, kioskUrl, playos-controller, greeting, extraModules ? [ ] }:
with lib;
let nixos = pkgs.importFromNixos ""; in
(nixos {
  configuration = {...}: {
    imports = [
      # general PlayOS modules
      ((import ./modules/playos.nix) {inherit pkgs version updateCert kioskUrl greeting playos-controller;})

      # system configuration
      ./configuration.nix
    ] ++ extraModules;
  };
  system = "x86_64-linux";
}).config.system.build.toplevel
