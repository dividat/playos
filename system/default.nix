# Build NixOS system
{pkgs, lib, version, updateCert, kioskUrl, playos-controller, greeting }:
with lib;
let nixos = pkgs.importFromNixos ""; in
(nixos {
  configuration = {...}: {
    imports = [
      # general PlayOS modules
      ((import ./modules/playos.nix) {inherit pkgs version updateCert kioskUrl greeting playos-controller;})

      # system configuration
      ./configuration.nix
    ];

    # As we control which state can be persisted past a reboot, we always set the stateVersion the system was built with.
    system.stateVersion = lib.trivial.release;

  };
  system = "x86_64-linux";
}).config.system.build.toplevel
