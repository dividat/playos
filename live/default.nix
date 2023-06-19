# Build NixOS system
{pkgs, lib, version, kioskUrl, greeting, playos-controller, application}:
with lib;
let nixos = pkgs.importFromNixos ""; in
(nixos {
  configuration = {...}: {
    imports = [
      # Base layer
      ((import ../base) {inherit pkgs version kioskUrl greeting playos-controller;})
      # Application-specific
      application

      (pkgs.importFromNixos "modules/installer/cd-dvd/iso-image.nix")
    ];

    config = {
      # Force use of already overlayed nixpkgs in modules
      nixpkgs.pkgs = pkgs;

      # ISO image customization
      isoImage.makeEfiBootable = true;
      isoImage.makeUsbBootable = true;
      isoImage.isoName = "playos-live-${version}.iso";
      isoImage.appendToMenuLabel = " Live System";

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

      # Live system does not self update
      playos.selfUpdate.enable = false;

      # There is no persistent state for a live system
      system.stateVersion = lib.trivial.release;

    };
  };
  system = "x86_64-linux";
}).config.system.build.isoImage
