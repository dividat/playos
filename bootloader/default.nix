{stdenv, fetchurl, binutils}:
let
 barebox = (import ./barebox-efi.nix) {
    inherit stdenv fetchurl binutils;
    defaultEnv = ./barebox-default-env;
  };
in
stdenv.mkDerivation {
  name = "esp";
  phases = [ "buildPhase" ];
 
  buildPhase = ''
    mkdir -p $out/EFI/BOOT
    cp ${barebox} $out/EFI/BOOT/BOOTX64.EFI
  '';
}
