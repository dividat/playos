{ version, updateUrl, kioskUrl }:

let

  nixpkgs = builtins.fetchGit {
    name = "nixpkgs-20.03-snapshot";
    url = "git@github.com:nixos/nixpkgs.git";
    rev = "3f690bfcd4adde6dd0733c2d9f8f4d61e09dfc60";
  };

  overlay =
    self: super: {

      importFromNixos = path: import (nixpkgs + "/nixos/" + path);

      rauc = (import ./rauc) super;

      dividat-driver = (import ./dividat-driver) {
        inherit (super) stdenv fetchurl;
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

      pacrunner = self.callPackage ./pacrunner.nix {};

      breeze-contrast-cursor-theme = super.callPackage ./breeze-contrast-cursor-theme {};

      ocamlPackages = super.ocamlPackages.overrideScope' (self: super: rec {

        semver = self.callPackage ./ocaml-modules/semver {};

        obus = self.callPackage ./ocaml-modules/obus {};

        mustache = self.callPackage ./ocaml-modules/mustache {};

        # Apply a patch allowing the utilization of proxies, see inspiration:
        # https://github.com/mirage/ocaml-cohttp/issues/459#issuecomment-186142690
        cohttp = self.callPackage ./ocaml-modules/cohttp {};
        cohttp-lwt = self.callPackage ./ocaml-modules/cohttp/lwt.nix {};
        cohttp-lwt-unix = self.callPackage ./ocaml-modules/cohttp/lwt-unix.nix {};
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
