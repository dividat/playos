# Build NixOS system
{pkgs, lib, version}:
with lib;
let nixos = pkgs.importFromNixos ""; in
(nixos {
  configuration = {...}: {
    imports = [
      # general PlayOS modules
      ((import ./modules/playos.nix) {inherit version pkgs;})

      # system configuration
      ./configuration.nix
    ];
  };
  system = "x86_64-linux";
}).config.system.build.toplevel
