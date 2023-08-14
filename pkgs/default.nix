{ applicationOverlays ? [] }:

let

  nixpkgs = builtins.fetchTarball {
    # nixos-23.05 2023-08-14
    url = "https://github.com/nixos/nixpkgs/archive/720e61ed8de116eec48d6baea1d54469b536b985.tar.gz";
    sha256 = "0ii10wmm8hqdp7bii7iza58rjaqs4z3ivv71qyix3qawwxx48hw9";
  };

  overlay =
    self: super: {

      importFromNixos = path: import (nixpkgs + "/nixos/" + path);

      rauc = (import ./rauc) super;

      ocamlPackages = super.ocamlPackages.overrideScope' (self: super: {
        semver = self.callPackage ./ocaml-modules/semver {};
        obus = self.callPackage ./ocaml-modules/obus {};
      });

    };

in

import nixpkgs {
  overlays = [ overlay ] ++ applicationOverlays;
}
