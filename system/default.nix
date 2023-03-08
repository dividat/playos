# Build NixOS system
{pkgs, lib, version, updateCert, kioskUrl, playos-controller, greeting, application }:
with lib;
let nixos = pkgs.importFromNixos ""; in
(nixos {
  configuration = {...}: {
    imports = [
      # General PlayOS modules
      ((import ./base) {inherit pkgs version updateCert kioskUrl greeting playos-controller;})

      # Application-specific module
      application
    ];

    # As we control which state can be persisted past a reboot, we always set the stateVersion the system was built with.
    system.stateVersion = lib.trivial.release;

  };
  system = "x86_64-linux";
}).config.system.build.toplevel
