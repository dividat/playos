{ applicationOverlays ? [] }:

let

  nixpkgs = builtins.fetchTarball {
    # nixos-24.11 2024-11-19
    url = "https://github.com/nixos/nixpkgs/archive/057f63b6dc1a2c67301286152eb5af20747a9cb4.tar.gz";
    sha256 = "17srzd2vif6if6mq6k5prd2kw7zhfnh6bg8ywgz28xj99rvgg4xz";
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
        ppx_protocol_conv = self.callPackage ./ocaml-modules/ppx_protocol_conv {};
        ppx_protocol_conv_jsonm = self.callPackage
            ./ocaml-modules/ppx_protocol_conv_jsonm {};
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
