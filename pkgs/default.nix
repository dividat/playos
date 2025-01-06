{ applicationOverlays ? [] }:

let

  nixpkgs = builtins.fetchTarball {
    # staging-next-24.11 2025-01-06
    url = "https://github.com/NixOS/nixpkgs/archive/fe7eff0b925b09b9e03031b0321486a4e923a649.tar.gz";
    sha256 = "1vrjmfs4acj4s7iry9jfygbk1q6smjbj552kx05bnr371wym0ypb";
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

    };

in

import nixpkgs {
  overlays = [ overlay ] ++ applicationOverlays;
}
