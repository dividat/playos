{ buildInstaller ? true
, buildBundle ? true
, buildDisk ? true }:
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
  version = "2018.12.0-dev";

  toplevels = (import ./system) {
    inherit (pkgs) pkgs lib;
    inherit version;
  };

  installer = (import ./installer) {
    inherit (pkgs) config pkgs lib;
    inherit version;
    toplevel = toplevels.system;
    grubCfg = ./bootloader/grub.cfg;
  };

  disk =
    if buildDisk then
      (import ./testing/disk) {
        inherit (pkgs) vmTools runCommand lib;
        inherit (installer) install-playos;
      }
    else
      null;

  raucBundle = (import ./rauc-bundle) {
    inherit (pkgs) stdenv perl pixz pathsFromGraph importFromNixos rauc;
    inherit version;
    cert = ./system/rauc/cert.pem;
    key = ./system/rauc/key.pem;
    toplevel = toplevels.system;
  };

  run-playos-in-vm = pkgs.substituteAll {
    src = ./bin/run-playos-in-vm.py;
    inherit version disk;
    inherit (pkgs) bindfs qemu;
    ovmf = "${pkgs.OVMF.fd}/FV/OVMF.fd";
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
    ln -s ${raucBundle} $out/playos-${version}.raucb
  '';

  shellHook = ''
    # EFI firmware for qemu
    export OVMF=${OVMF.fd}/FV/OVMF.fd
    export PATH=$PATH:"$(pwd)/bin"
  '';

}
