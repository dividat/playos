# Build an installable system image assuming a disk layout of a full A/B installation
{pkgs, lib, updateCert, kioskUrl, playos-controller, application,
 isTestBuild ? false
}:
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
    ]
    # TODO: move this to a 'test' overlay in the application?
    ++ lib.lists.optional isTestBuild
        (import ../testing/end-to-end/profile.nix { inherit pkgs; });

    # Storage
    fileSystems = {
      "/boot" = {
        device = "/dev/disk/by-label/ESP";
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
