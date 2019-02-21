# Build NixOS system
{pkgs, lib, version, updateCert, kioskUrl, playos-controller}:
with lib;
let nixos = pkgs.importFromNixos ""; in
(nixos {
  configuration = {...}: {
    imports = [
      # general PlayOS modules
      # ((import ./modules/playos.nix) {inherit pkgs version updateCert kioskUrl playos-controller;})

      # system configuration
      # ./configuration.nix

      (pkgs.importFromNixos "modules/installer/cd-dvd/iso-image.nix")

      # Play Kiosk and Driver
      ../system/play-kiosk.nix

    ];

    options = {
      playos.version = mkOption {
        type = types.string;
        default = version;
      };

      playos.kioskUrl = mkOption {
        type = types.string;
      };

      playos.updateCert = mkOption {
        type = types.package;
      };
    };

    config = {
      # Force use of already overlayed nixpkgs in modules
      nixpkgs.pkgs = pkgs;

      # EFI booting
      isoImage.makeEfiBootable = true;

      # USB booting
      isoImage.makeUsbBootable = true;

      isoImage.isoName = "playos-live-${version}.iso";

      playos = {
        inherit version updateCert kioskUrl;
      };

      # Start controller
      systemd.services.playos-controller = {
        description = "PlayOS Controller";
        serviceConfig = {
          ExecStart = "${playos-controller}/bin/playos-controller";
          User = "root";
          RestartSec = "10s";
          Restart = "always";
        };
        wantedBy = [ "multi-user.target" ];
        requires = [ "rauc" "connman" ];
        after = [ "rauc" "connman" ];
      };
    };

  };
  system = "x86_64-linux";
}).config.system.build.isoImage
