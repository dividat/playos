{ applicationOverlays ? [] }:

let

  nixpkgs = builtins.fetchTarball {
    # nixos-24.05 2024-10-07
    url = "https://github.com/nixos/nixpkgs/archive/ecbc1ca8ffd6aea8372ad16be9ebbb39889e55b6.tar.gz";
    sha256 = "0yfaybsa30zx4bm900hgn3hz92javlf4d47ahdaxj9fai00ddc1x";
  };

  overlay =
    self: super: {

      importFromNixos = path: import (nixpkgs + "/nixos/" + path);

      rauc = (import ./rauc) super;

      ocamlPackages = super.ocamlPackages.overrideScope' (self: super: {
        semver = self.callPackage ./ocaml-modules/semver {};
        obus = self.callPackage ./ocaml-modules/obus {};
        opium = self.callPackage ./ocaml-modules/opium {};
        opium_kernel = self.callPackage ./ocaml-modules/opium_kernel {};
      });

      # fixes getExe warning, used in tests
      # Should be obsolete after upgrading to nixpkgs 24.05: https://github.com/NixOS/nixpkgs/pull/273952
      tinyproxy = super.tinyproxy.overrideAttrs (_: prev: {
        meta = prev.meta // {
          mainProgram = "tinyproxy";
        };
      });

    };

in

import nixpkgs {
  overlays = [ overlay ] ++ applicationOverlays;
}
