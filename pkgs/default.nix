{ version, updateUrl, kioskUrl }:

let

  nixpkgs = import ./patch-nixpkgs.nix {
    src = builtins.fetchGit {
      name = "nixos-21.05-2021-08-02";
      url = "https://github.com/nixos/nixpkgs";
      ref = "refs/heads/nixos-21.05";
      rev = "d4590d21006387dcb190c516724cb1e41c0f8fdf";
    };
    patches = [
      # Fix merged in master 2021/08/12: https://github.com/NixOS/nixpkgs/pull/127595
      ./patches/nixos-wireless-use-udev-to-wait-for-interfaces.patch
    ];
  };

  overlay =
    self: super: {

      importFromNixos = path: import (nixpkgs + "/nixos/" + path);

      rauc = (import ./rauc) super;

      dividat-driver = (import ./dividat-driver) {
        inherit (super) stdenv fetchFromGitHub buildGoModule;
        pkgs = self;
      };

      playos-kiosk-browser = import ../kiosk {
        pkgs = self;
        system_name = "PlayOS";
        system_version = version;
      };

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
