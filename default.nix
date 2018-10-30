let nixpkgs = (import ./nixpkgs).nixpkgs {
    overlays = [ (import ./pkgs) ];
}; 
in
let 
  importFromNixos = (import ./nixpkgs).importFromNixos;
  nixos = importFromNixos "";
  makeDiskImage = importFromNixos "lib/make-disk-image.nix"; 
  makeSystemTarball = importFromNixos "lib/make-system-tarball.nix";

  version = "2018.10.1-dev";

  system = (import ./system) {
    inherit (nixpkgs) config pkgs lib;
    inherit nixos;
  };

  systemTarball = makeSystemTarball {
    inherit (nixpkgs) stdenv perl pixz pathsFromGraph;

    fileName = "system";

    contents = [
      {
        source = system.config.system.build.initialRamdisk 
          + "/" + system.config.system.boot.loader.initrdFile;
        target = "/initrd";
      }
      {
        source = system.config.system.build.kernel + "/bzImage";
        target = "/kernel";
      }
      {
        source = system.config.system.build.toplevel + "/init" ;
        target = "/init";
      }
    ];

    storeContents = [{ 
        object = system.config.system.build.toplevel;
        symlink = "/run/current-system";
      }];
  } + "/tarball/system.tar.xz";

  disk = (import ./lib/make-disk-image.nix) {
    inherit (nixpkgs) pkgs lib;
    inherit systemTarball;
  } + "/nixos.img";


  raucBundle = (import ./lib/make-rauc-bundle.nix) {
    inherit (nixpkgs) stdenv rauc;
    inherit version;
    cert = ./system/rauc/cert.pem;
    key = ./system/rauc/key.pem;
    inherit systemTarball;
  };

in
with nixpkgs;
stdenv.mkDerivation {
  name = "dividat-linux-${version}";

  buildInputs = [
    rauc
  ];

  inherit systemTarball;
  inherit disk;
  inherit raucBundle;

  buildCommand = ''
    mkdir -p $out
    ln -s ${systemTarball} $out/system.tar.xz
    ln -s ${disk} $out/disk.img
    ln -s ${raucBundle} $out/bundle-${version}.raucb
  '';

  shellHook = ''
    export out=./build/out
    export TEMP=./build/temp

    # EFI firmware for qemu
    export OVMF=${OVMF.fd}/FV/OVMF.fd
  '';

}
