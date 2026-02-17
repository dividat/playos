# Build NixOS system
{pkgs, lib, kioskUrl, playos-controller, application, squashfsCompressionOpts}:
with lib;
let nixos = pkgs.importFromNixos ""; in
(nixos {
  configuration = {...}: {
    imports = [
      # Base layer
      ((import ../base) {
        inherit pkgs kioskUrl playos-controller;
        inherit (application) safeProductName fullProductName greeting version;
      })
      # Application-specific
      application.module

      (pkgs.importFromNixos "modules/installer/cd-dvd/iso-image.nix")
    ];

    config = {
      # ISO image customization
      isoImage = {
        makeEfiBootable = true;
        makeUsbBootable = true;
        isoName = "${application.safeProductName}-live-${application.version}.iso";
        appendToMenuLabel = " Live System";
      } // lib.optionalAttrs (squashfsCompressionOpts != null) { squashfsCompression = squashfsCompressionOpts; };

      # Set up as completely volatile system
      fileSystems."/boot" = {
        device = "tmpfs";
        fsType = "tmpfs";
        options = [ "mode=0755" ];
      };
      playos.storage = {
        systemPartition.enable = false;
        persistentDataPartition = {
          device = "tmpfs";
          fsType = "tmpfs";
          options = [ "mode=0755" ];
        };
      };

      # Live system does not self update or need monitoring
      playos.selfUpdate.enable = false;
      playos.monitoring.enable = mkForce false;

      # There is no persistent state for a live system
      system.stateVersion = lib.trivial.release;

    };
  };
  system = "x86_64-linux";
}).config.system.build.isoImage
