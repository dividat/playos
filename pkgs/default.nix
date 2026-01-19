{ applicationOverlays ? [] }:

let

  nixpkgs = builtins.fetchTarball {
    # release-24.11 2025-02-10
    url = "https://github.com/NixOS/nixpkgs/archive/edd84e9bffdf1c0ceba05c0d868356f28a1eb7de.tar.gz";
    sha256 = "1gb61gahkq74hqiw8kbr9j0qwf2wlwnsvhb7z68zhm8wa27grqr0";
  };

  overlay =
    self: super: {

      importFromNixos = path: import (nixpkgs + "/nixos/" + path);

      rauc = (import ./rauc) super;

      ocamlPackages = super.ocamlPackages.overrideScope (self: super: {
        semver = self.callPackage ./ocaml-modules/semver {};
        obus = self.callPackage ./ocaml-modules/obus {};
        opium = self.callPackage ./ocaml-modules/opium {};
        opium_kernel = self.callPackage ./ocaml-modules/opium_kernel {};
        ppx_protocol_conv = self.callPackage ./ocaml-modules/ppx_protocol_conv {};
        ppx_protocol_conv_jsonm = self.callPackage
            ./ocaml-modules/ppx_protocol_conv_jsonm {};
      });

      connman = (import ./connman) super;

      python3Packages = super.python3Packages.overrideScope (self: super: {
        playos-proxy-utils = self.callPackage ../proxy-utils {};
      });

      qt6 = super.qt6.overrideScope (qtself: qtsuper: {
        qtvirtualkeyboard = (import ./qtvirtualkeyboard) { pkgs = super; qt6 = qtsuper; };
      });

      focus-shift = self.callPackage ./focus-shift.nix {};

      playos-diagnostics = self.callPackage ./playos-diagnostics {};

      telegraf = (import ./telegraf.nix) super;
    };
in

import nixpkgs {
  overlays = [ overlay ] ++ applicationOverlays;
}
