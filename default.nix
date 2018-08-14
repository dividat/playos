let nixpkgs = import ./nix/nixpkgs.nix; in
let nixpkgs_musl = nixpkgs { crossSystem = { config = "x86_64-unknown-linux-musl"; };}; in
with nixpkgs {
  overlays = [ (import ./nix/overlay.nix) ];
};
let
  alpine = import ./alpine {
    inherit stdenv fetchurl gzip nixpkgs_musl proot;
  };

  aports = import ./aports {
    inherit fetchurl;
    apkBuilder = alpine.apkBuilder;
  };
in
stdenv.mkDerivation {
    name = "divialpine";
    builder = "${bash}/bin/bash";
    buildInputs = [
      proot

      libguestfs

      #((import ./barebox) {inherit stdenv fetchurl libftdi1 pkgconfig;})

      alpine.apk-tools-static
      alpine.apk2nix

      qemu
      OVMF.fd
    ];

    shellHook = ''
      # Hack to fix libguestfs in nixpkgs (without recompiling it)
      # TODO: use fix in nixpkgs (https://github.com/NixOS/nixpkgs/pull/37562)
      export LIBGUESTFS_PATH=${libguestfs}/lib/guestfs

      export OVMF=${OVMF.fd}/FV/OVMF.fd

      # See https://github.com/proot-me/PRoot/issues/106
      export PROOT_NO_SECCOMP=1

      export ROOT_FS=${alpine.bootable-system}
    '';
}
