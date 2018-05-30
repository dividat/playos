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

      libguestfs

      # apk-tools-static, prebuilt static binary of apk
      apk-tools-static

      # apk-tools needs to be compiled with musl.
      ((import ./nix/apk-tools)  nixpkgs_musl)

    ];

    shellHook = ''
      # Hack to fix libguestfs in nixpkgs (without recompiling it)
      # TODO: use fix in nixpkgs (https://github.com/NixOS/nixpkgs/pull/37562)
      export LIBGUESTFS_PATH=${libguestfs}/lib/guestfs
    '';
}
