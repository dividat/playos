{ version, updateUrl, kioskUrl, activeVirtualTerminals ? [] }:

let

  nixpkgs = builtins.fetchTarball {
    # nixos-22.05 2022-10-26
    url = "https://github.com/nixos/nixpkgs/archive/e6e675cafe6a1d1b0eeb9ac3fe046091244b714e.tar.gz";
    sha256 = "1dr7fw8a5c793xlhfz929bwhi2bmw97kkcz9x8838br2by0frdkn";
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
