{buildInstaller ? true, buildBundle ? true}:
let
  pinnedNixpkgs = import ./nixpkgs;
  pkgs = pinnedNixpkgs.nixpkgs {
    overlays = [
      (import ./pkgs)
      (self: super: {
      inherit (pinnedNixpkgs) importFromNixos;
      })
    ];
};
in
let
  nixos = pkgs.importFromNixos "";
  makeDiskImage = pkgs.importFromNixos "lib/make-disk-image.nix";
  makeSystemTarball = pkgs.importFromNixos "lib/make-system-tarball.nix";

  version = "2018.12.0-dev";

  toplevels = (import ./system) {
    inherit (pkgs) pkgs lib;
    inherit nixos version;
  };

  systemTarball = makeSystemTarball {
    inherit (pkgs) stdenv perl pixz pathsFromGraph;

    fileName = "system";

    contents = [
      {
        source = toplevels.system + "/initrd";
        target = "/initrd";
      }
      {
        source = toplevels.system + "/kernel";
        target = "/kernel";
      }
      {
        source = toplevels.system + "/init" ;
        target = "/init";
      }
    ];

    storeContents = [{
        object = toplevels.system;
        symlink = "/run/current-system";
      }];
  } + "/tarball/system.tar.xz";

  installer = (import ./installer) {
    inherit (pkgs) config pkgs lib;
    inherit nixos;
    inherit version;
    toplevel = toplevels.system;
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

  run-playos-in-vm = pkgs.substituteAll {
    src = ./bin/run-playos-in-vm.py;
    inherit version;
    bindfs = "${pkgs.bindfs}/bin/bindfs";
    toplevel = toplevels.testing;
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

    # System toplevels
    ln -s ${toplevels.system} $out/system
    ln -s ${toplevels.testing} $out/testing

    # Helper to run in vm
    mkdir -p $out/bin
    cp ${run-playos-in-vm} $out/bin/run-playos-in-vm
    chmod +x $out/bin/run-playos-in-vm
    patchShebangs $out/bin/run-playos-in-vm
  ''
  # Installer ISO image
  + pkgs.lib.optionalString buildInstaller ''
    ln -s ${installer.isoImage}/iso/playos-installer-${version}.iso $out/playos-installer-${version}.iso
  ''
  # RAUC bundle
  + pkgs.lib.optionalString buildBundle ''
    ln -s ${raucBundle} $out/bundle-${version}.raucb
  '';

  shellHook = ''
    # EFI firmware for qemu
    export OVMF=${OVMF.fd}/FV/OVMF.fd
    export PATH=$PATH:"$(pwd)/bin"
  '';

}
