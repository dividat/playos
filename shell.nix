let nixpkgs = (import ./nixpkgs).nixpkgs {
    overlays = [ (import ./pkgs) ];
}; 
in
with nixpkgs;
let diskImage = import ./default.nix; in
stdenv.mkDerivation {
  name = "dividat-linux-dev-shell";

  buildInputs = [
    # EFI firmware for qemu
    OVMF.fd
  ];

  shellHook = ''
    export DIVIDAT_LINUX_DISK_IMAGE=${diskImage}/nixos.img
    export OVMF=${OVMF.fd}/FV/OVMF.fd
  '';
}
