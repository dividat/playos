{ version, updateUrl, kioskUrl }:

let

  nixpkgs = (import <nixpkgs> {}).fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "19.03";
    sha256 = "0q2m2qhyga9yq29yz90ywgjbn9hdahs7i8wwlq7b55rdbyiwa5dy";
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

      breeze-contrast-cursor-theme = super.callPackage ./breeze-contrast-cursor-theme {};

      ocamlPackages = super.ocamlPackages.overrideScope' (self: super: {

        hmap = self.callPackage ./ocaml-modules/hmap {};

        semver = self.callPackage ./ocaml-modules/semver {};

        opium_kernel = self.callPackage ./ocaml-modules/opium_kernel {};
        opium = self.callPackage ./ocaml-modules/opium {};

        obus = self.callPackage ./ocaml-modules/obus {};

        mustache = self.callPackage ./ocaml-modules/mustache {};

        cohttp-lwt-jsoo = super.cohttp.overrideAttrs (oldAttrs: {
          buildPhase = "jbuilder build -p cohttp-lwt-jsoo";
          propagatedBuildInputs = with self; [ cohttp cohttp-lwt ocaml_lwt js_of_ocaml js_of_ocaml-lwt js_of_ocaml-ppx ppx_tools_versioned ];
        });
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
