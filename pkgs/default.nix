{ version, updateUrl, kioskUrl, activeVirtualTerminals ? [] }:

let

  nixpkgs = builtins.fetchTarball {
    # nixos-21.11 2022-03-07
    url = "https://github.com/nixos/nixpkgs/archive/9b1c7ba323732ddc85a51850a7f10ecc5269b8e9.tar.gz";
    sha256 = "12m4bkbqdnwxq607w58fqnmx8wnii2f6g2rjlb4wwp79apkrzwb6";
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
