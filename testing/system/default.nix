{pkgs, lib, version, kioskUrl, playos-controller, greeting, application}:

let nixos = pkgs.importFromNixos ""; in

(nixos {
  configuration = {...}: {
  imports = [
    # General PlayOS modules
    (import ../../system/base { inherit pkgs version kioskUrl greeting playos-controller; })

    # Application-specific
    application

    # Testing machinery
    (import ./testing.nix { inherit lib pkgs; })
  ];
  };
  system = "x86_64-linux";
}).config.system.build.toplevel
