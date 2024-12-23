{ applicationOverlays ? [] }:

let

  nixpkgs = builtins.fetchTarball {
    # nixos-23.11 2024-03-18
    url = "https://github.com/nixos/nixpkgs/archive/614b4613980a522ba49f0d194531beddbb7220d3.tar.gz";
    sha256 = "1kipdjdjcd1brm5a9lzlhffrgyid0byaqwfnpzlmw3q825z7nj6w";
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
