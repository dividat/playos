{pkgs, lib, version}:
let nixos = pkgs.importFromNixos ""; in
(nixos {
  configuration = {...}: {
  imports = [
    # general PlayOS modules
    ((import ../../system/modules/playos.nix) {inherit version pkgs;})

    # system configuration
    ../../system/configuration.nix

    # Testing machinery
    # FIXME: the importFromNixos should be in the pkgs anyways which is passed to the testing.nix module. But I get an infinite recursion somewhere if using from pkgs.
    ((import ./testing.nix) {inherit (pkgs) importFromNixos;})
  ];
  };
  system = "x86_64-linux";
}).config.system.build.toplevel

