# Build an installable system image assuming a disk layout of a full A/B installation
{pkgs, lib, updateCert, kioskUrl, playos-controller, application, extraModules ? [ ] }:
with lib;
let nixos = pkgs.importFromNixos ""; in
(nixos {
  configuration = {...}: {
    imports = [
      # Base layer of PlayOS
      ((import ../base) {
        inherit pkgs kioskUrl playos-controller;
        inherit (application) safeProductName fullProductName greeting version;
      })

      # Application-specific module
      application.module
    ] ++ extraModules;

    # Storage
    fileSystems = {
      "/boot" = {
        device = "/dev/disk/by-label/ESP";
        fsType = "vfat";
      };
    };
    playos.storage = {
      systemPartition = {
        enable = true;
        device = "/dev/root";
        options = [ "ro" ];
      };
      persistentDataPartition.device = "/dev/disk/by-label/data";
    };

    playos.selfUpdate = {
      enable = true;
      updateCert = updateCert;
    };

    # As we control which state can be persisted past a reboot, we always set the stateVersion the system was built with.
    system.stateVersion = lib.trivial.release;

  };
  system = "x86_64-linux";
}).config.system.build.toplevel
