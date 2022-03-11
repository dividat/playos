{pkgs, lib, version, updateCert, kioskUrl, playos-controller, greeting}:

let nixos = pkgs.importFromNixos ""; in

(nixos {
  configuration = {...}: {
  imports = [
    # general PlayOS modules
    (import ../../system/modules/playos.nix { inherit pkgs version updateCert kioskUrl greeting playos-controller; })

    # system configuration
    ../../system/configuration.nix

    # Testing machinery
    (import ./testing.nix { inherit lib pkgs; })
  ];
  };
  system = "x86_64-linux";
}).config.system.build.toplevel
