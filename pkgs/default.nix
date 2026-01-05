{ applicationOverlays ? [] }:

let

  nixpkgs = builtins.fetchTarball {
    # release-25.11 2026-01-05
    url = "https://github.com/NixOS/nixpkgs/archive/30a3c519afcf3f99e2c6df3b359aec5692054d92.tar.gz";
    sha256 = "13rp7g4ivphc70z6fdb2gf6angzr6qm2vrx32nk286nli991117h";
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
    };
in

import nixpkgs {
  overlays = [ overlay ] ++ applicationOverlays;
}
