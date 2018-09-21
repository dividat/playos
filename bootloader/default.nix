{stdenv, fetchurl, binutils}:
let
 barebox = (import ./barebox-efi.nix) {
    inherit stdenv fetchurl binutils;
    defaultEnv = ./barebox-default-env;
  };
in
stdenv.mkDerivation {
  name = "esp.tar.xz";
  phases = [ "buildPhase" ];
 
  buildPhase = ''
    mkdir -p $TMPDIR/EFI/BOOT
    cp ${barebox} $TMPDIR/EFI/BOOT/BOOTX64.EFI
    cd $TMPDIR
    tar --sort=name --mtime='@1' --owner=0 --group=0 --numeric-owner -cvJf $out *
  '';
}
