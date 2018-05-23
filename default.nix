let nixpkgs = import ./nix/nixpkgs.nix; in
with nixpkgs {};
stdenv.mkDerivation {
    name = "divialpine";
    builder = "${bash}/bin/bash";
    buildInputs = [

      # apk-tools needs to be compiled with musl.
      ((import ./nix/apk-tools) (nixpkgs {
        crossSystem = {
          config = "x86_64-unknown-linux-musl";
        };
      }))

    ];
}
