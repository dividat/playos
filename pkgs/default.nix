{ applicationOverlays ? [] }:

let

  nixpkgs = builtins.fetchTarball {
    # release-25.11 2026-04-30
    url = "https://github.com/NixOS/nixpkgs/archive/5a9c58fc6ac2ec48bf9cf4c07de27f912b1ed1cc.tar.gz";
    sha256 = "0s0r78hddzrb5hnc95l0qlg6lfk7lwp3sl49adj3fc96yjfr63va";
  };

  overlay =
    self: super: {

      importFromNixos = path: import (nixpkgs + "/nixos/" + path);

      # use RAUC from skeleton
      rauc = (import ../skeleton/pkgs).rauc;

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
        playos-test-helpers = self.callPackage ../testing/helpers {};
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
