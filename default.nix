let nixpkgs = (import ./nixpkgs).nixpkgs {
    overlays = [ (import ./pkgs) ];
}; 
in
let 
  importFromNixos = (import ./nixpkgs).importFromNixos;
  nixos = importFromNixos "";
  makeDiskImage = importFromNixos "lib/make-disk-image.nix"; 
  makeSystemTarball = importFromNixos "lib/make-system-tarball.nix";

  version = "2018.12.0-dev";

  system = (import ./system) {
    inherit (nixpkgs) config pkgs lib;
    inherit nixos version;
  };

  systemTarball = makeSystemTarball {
    inherit (nixpkgs) stdenv perl pixz pathsFromGraph;

    fileName = "system";

    contents = [
      {
        source = system + "/initrd";
        target = "/initrd";
      }
      {
        source = system + "/kernel";
        target = "/kernel";
      }
      {
        source = system + "/init" ;
        target = "/init";
      }
    ];

    storeContents = [{ 
        object = system;
        symlink = "/run/current-system";
      }];
  } + "/tarball/system.tar.xz";

  installer = (import ./installer) {
    inherit (nixpkgs) config pkgs lib;
    inherit nixos importFromNixos;
    inherit systemTarball version;
    grubCfg = ./bootloader/grub.cfg;
  };

  disk = (import ./lib/make-disk-image.nix) {
    inherit (nixpkgs) pkgs lib;
    inherit systemTarball;
    inherit (installer) install-playos;
  } + "/nixos.img";

  raucBundle = (import ./lib/make-rauc-bundle.nix) {
    inherit (nixpkgs) stdenv rauc;
    inherit version;
    cert = ./system/modules/update-mechanism/cert.pem;
    key = ./system/modules/update-mechanism/key.pem;
    inherit systemTarball;
  };

in
with nixpkgs;
stdenv.mkDerivation {
  name = "playos-${version}";

  buildInputs = [
    rauc
    (python36.withPackages(ps: with ps; [pyparted]))
    installer.install-playos
  ];

  inherit systemTarball;
  inherit disk;
  inherit raucBundle;

  buildCommand = ''
    mkdir -p $out
    ln -s ${systemTarball} $out/system.tar.xz
    ln -s ${disk} $out/disk.img
    ln -s ${installer.isoImage}/iso/playos-installer-${version}.iso $out/playos-installer-${version}.iso
    ln -s ${raucBundle} $out/bundle-${version}.raucb
  '';

  shellHook = ''
    # EFI firmware for qemu
    export OVMF=${OVMF.fd}/FV/OVMF.fd
    
    export PATH=$PATH:"$(pwd)/bin"
  '';

}
