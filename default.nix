let nixpkgs = (import ./nixpkgs).nixpkgs {
    overlays = [ (import ./pkgs) ];
}; 
in
let 
  importFromNixos = (import ./nixpkgs).importFromNixos;
  nixos = importFromNixos "";
  makeDiskImage = importFromNixos "lib/make-disk-image.nix"; 
  makeSystemTarball = importFromNixos "lib/make-system-tarball.nix";

  gitignore = (import ./lib/gitignore.nix) {inherit (nixpkgs) lib fetchFromGitHub;};

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
  };
in
with nixpkgs;
stdenv.mkDerivation {
  name = "dividat-linux";

  buildInputs = [
    rauc
  ];

  inherit systemTarball;
  inherit disk;

  phases = [ "buildPhase" ];

  buildPhase = ''
    mkdir -p $out/tarballs
    cp $systemTarball $out/tarballs/system.tar.xz

    mkdir -p $out/test
    cp $disk/nixos.img $out/test/disk.img
  '';

  shellHook = ''
    # EFI firmware for qemu
    export OVMF=${OVMF.fd}/FV/OVMF.fd
  '';

}
