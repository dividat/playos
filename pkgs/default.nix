{ version, updateUrl, kioskUrl }:

let

  nixpkgs = import ./patch-nixpkgs.nix {
    src = builtins.fetchGit {
      name = "nixos-21.11-2021-03-07";
      url = "https://github.com/nixos/nixpkgs";
      ref = "refs/heads/nixos-21.11";
      rev = "9b1c7ba323732ddc85a51850a7f10ecc5269b8e9";
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
    overlays = [ overlay ];
  }
