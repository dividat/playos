let nixpkgs = import ./nix/nixpkgs.nix; in
let nixpkgs_musl = nixpkgs { crossSystem = { config = "x86_64-unknown-linux-musl"; };}; in
with nixpkgs {
  overlays = [ (import ./nix/overlay.nix) ];
};
stdenv.mkDerivation {
    name = "divialpine";
    builder = "${bash}/bin/bash";
    buildInputs = [
      proot

      # apk-tools-static, prebuilt static binary of apk
      apk-tools-static

      # apk-tools needs to be compiled with musl.
      ((import ./nix/apk-tools)  nixpkgs_musl)

    ];
}
