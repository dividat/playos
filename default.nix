{buildInstaller ? true, buildBundle ? true}:
let pkgs = (import ./nixpkgs).nixpkgs {
    overlays = [
      (import ./pkgs)
      (self: super: {
        importFromNixos = (import ./nixpkgs).importFromNixos;
      })
    ];
};
in
let
  nixos = pkgs.importFromNixos "";
  makeDiskImage = pkgs.importFromNixos "lib/make-disk-image.nix";
  makeSystemTarball = pkgs.importFromNixos "lib/make-system-tarball.nix";

  version = "2018.12.0-dev";

  systemTopLevel = (import ./system) {
    inherit (pkgs) pkgs lib;
    inherit nixos version;
  };

  systemTarball = makeSystemTarball {
    inherit (pkgs) stdenv perl pixz pathsFromGraph;

    fileName = "system";

    contents = [
      {
        source = systemTopLevel + "/initrd";
        target = "/initrd";
      }
      {
        source = systemTopLevel + "/kernel";
        target = "/kernel";
      }
      {
        source = systemTopLevel + "/init" ;
        target = "/init";
      }
    ];

    storeContents = [{ 
        object = systemTopLevel;
        symlink = "/run/current-system";
      }];
  } + "/tarball/system.tar.xz";

  installer = (import ./installer) {
    inherit (pkgs) config pkgs lib;
    inherit nixos;
    inherit systemTopLevel version;
    grubCfg = ./bootloader/grub.cfg;
  };

  disk = (import ./lib/make-disk-image.nix) {
    inherit (pkgs) pkgs lib;
    inherit (installer) install-playos;
  } + "/nixos.img";

  raucBundle = (import ./lib/make-rauc-bundle.nix) {
    inherit (pkgs) stdenv rauc;
    inherit version;
    cert = ./system/rauc/cert.pem;
    key = ./system/rauc/key.pem;
    inherit systemTarball;
  };

in
with pkgs;
stdenv.mkDerivation {
  name = "playos-${version}";

  buildInputs = [
    rauc
    (python36.withPackages(ps: with ps; [pyparted]))
    installer.install-playos
  ];

  # inherit disk;

  buildCommand = ''
    mkdir -p $out
    ln -s ${systemTopLevel} $out/system
  '' + pkgs.lib.optionalString buildInstaller ''
    ln -s ${installer.isoImage}/iso/playos-installer-${version}.iso $out/playos-installer-${version}.iso
  '' + pkgs.lib.optionalString buildBundle ''
    ln -s ${raucBundle} $out/bundle-${version}.raucb
  '';

  shellHook = ''
    # EFI firmware for qemu
    export OVMF=${OVMF.fd}/FV/OVMF.fd
    export PATH=$PATH:"$(pwd)/bin"
  '';

}
