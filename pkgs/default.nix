{ version, updateUrl, kioskUrl }:

let

  nixpkgs = import ./patch-nixpkgs.nix {
    src = builtins.fetchGit {
      name = "nixpkgs-20.09";
      url = "git@github.com:nixos/nixpkgs.git";
      rev = "cd63096d6d887d689543a0b97743d28995bc9bc3";
      ref = "refs/tags/20.09";
    };
    patches = [
      # Fixed on *master* but not on *nixos-20.09*, as of 2020/11/30
      ./patches/fix-lvm2-warnings-on-activation.patch
      # Fix from unmerged PR as of 2020/12/14: https://github.com/NixOS/nixpkgs/pull/104722
      ./patches/fix-wpa_supplicant-udev-restart.patch
    ];
  };

  overlay =
    self: super: {

      importFromNixos = path: import (nixpkgs + "/nixos/" + path);

      rauc = (import ./rauc) super;

      dividat-driver = (import ./dividat-driver) {
        inherit (super) stdenv fetchFromGitHub buildGoPackage;
        pkgs = self;
      };

      playos-kiosk-browser = import ../kiosk {
        pkgs = self;
        system_name = "PlayOS";
        system_version = version;
      };

      # pin pcsclite to 1.8.23 because of break in ABI (https://github.com/LudovicRousseau/PCSC/commit/984f84df10e2d0f432039e3b31f94c74e95092eb)
      pcsclite = super.pcsclite.overrideAttrs (oldAttrs: rec {
        version = "1.8.23";
        src = super.fetchurl {
          url = "https://pcsclite.apdu.fr/files/pcsc-lite-${version}.tar.bz2";
          sha256 = "1jc9ws5ra6v3plwraqixin0w0wfxj64drahrbkyrrwzghqjjc9ss";
        };
      });

      breeze-contrast-cursor-theme = super.callPackage ./breeze-contrast-cursor-theme {};

      ocamlPackages = super.ocamlPackages.overrideScope' (self: super: {
        semver = self.callPackage ./ocaml-modules/semver {};
        obus = self.callPackage ./ocaml-modules/obus {};
      });

      # Controller
      playos-controller = import ../controller {
        pkgs = self;
        version = version;
        updateUrl = updateUrl;
        kioskUrl = kioskUrl;
      };

    };

in

  import nixpkgs {
    overlays = [ overlay ];
  }
