# Build NixOS system
{pkgs, lib, version, updateCert, kioskUrl, greeting, playos-controller}:
with lib;
let nixos = pkgs.importFromNixos ""; in
(nixos {
  configuration = {...}: {
    imports = [
      # general PlayOS modules
      ((import ../system/modules/playos.nix) {inherit pkgs version updateCert kioskUrl greeting playos-controller;})
      # Play Kiosk and Driver
      ../system/play-kiosk.nix
      # Networking
      ../system/networking
      # Localization
      ../system/localization.nix

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
      systemPartition.enable = mkForce false;
      volatileRoot.persistentDataPartition = {
        device = "tmpfs";
        fsType = "tmpfs";
        options = [ "mode=0755" ];
      };

    };

  };
  system = "x86_64-linux";
}).config.system.build.isoImage
