{pkgs, lib, kioskUrl, playos-controller, application}:

let nixos = pkgs.importFromNixos ""; in

(nixos {
  configuration = {...}: {
  imports = [
    # Base layer
    (import ../../base {
      inherit pkgs kioskUrl playos-controller;
      inherit (application) fullProductName greeting version;
    })

    # Application-specific
    application.module

    # Testing machinery
    (import ./testing.nix { inherit lib pkgs; })
  ];
  };
  system = "x86_64-linux";
}).config.system.build.toplevel
