{ version, updateUrl, kioskUrl, activeVirtualTerminals ? [] }:

let

  nixpkgs = import ./patch-nixpkgs.nix {
    src = builtins.fetchGit {
      name = "nixos-22.05-2022-10-26";
      url = "https://github.com/nixos/nixpkgs";
      ref = "refs/heads/nixos-22.05";
      rev = "e6e675cafe6a1d1b0eeb9ac3fe046091244b714e";
    };
    patches = [];
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
    overlays = [
      overlay
      (import ./xorg { inherit activeVirtualTerminals; })
    ];
  }
