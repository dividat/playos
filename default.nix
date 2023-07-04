let
  bootstrap = (import <nixpkgs> {});
in
{
  ###### Configuration that is passed into the build system #######

  # Certificate used for verification of update bundles
  updateCert ? (bootstrap.lib.warn "Using dummy update certificate. Build artifacts can only be used for local development." ./pki/dummy/cert.pem)

  # url from where updates should be fetched
, updateUrl ? "http://localhost:9000/"
, deployUrl ? "s3://dist-test.dividat.ch/releases/playos/test/"

  # url where kiosk points
, kioskUrl ? "https://play.dividat.com"

, applicationPath ? ./application.nix

  ##### Allow disabling the build of unused artifacts when developing/testing #####
, buildInstaller ? true
, buildBundle ? true
, buildDisk ? true
, buildLive ? true
}:

let

  application = import applicationPath;

  pkgs = import ./pkgs (with application; {
    inherit version updateUrl kioskUrl;
    applicationOverlays = application.overlays;
  });

  # lib.makeScope returns consistent set of packages that depend on each other (and is my new favorite nixpkgs trick)
  components = with pkgs; lib.makeScope newScope (self: with self; {

    inherit updateUrl deployUrl kioskUrl;
    inherit (application) version fullProductName;

    greeting = lib.attrsets.attrByPath [ "greeting" ] (label: label) application;

    # Documentations
    docs = callPackage ./docs {};

    # Certificate used for verification of update bundles
    updateCert = copyPathToStore updateCert;

    # System image as used in full installation
    systemImage = callPackage ./system-image { application = application; };

    # USB live system
    live = callPackage ./live { application = application; };

    # Installation script
    install-playos = callPackage ./installer/install-playos {
      grubCfg = ./bootloader/grub.cfg;
    };

    # Rescue system
    rescueSystem = callPackage ./bootloader/rescue {};

    # Installer ISO image
    installer = callPackage ./installer {};

    # Script to deploy updates
    deploy-playos-update = callPackage ./deployment/deploy-playos-update {};

    # RAUC bundle
    unsignedRaucBundle = callPackage ./rauc-bundle {};

    # NixOS system toplevel with test machinery
    testingToplevel = callPackage ./testing/system { application = application; };

    # Disk image containing pre-installed system
    disk = if buildDisk then callPackage ./testing/disk {} else null;

    # Script for spinning up VMs
    run-playos-in-vm = callPackage ./testing/run-playos-in-vm {};

  });

in

with pkgs; stdenv.mkDerivation {
  name = "playos-${components.version}";

  buildInputs = [
    rauc
    (python39.withPackages(ps: with ps; [pyparted]))
    components.install-playos
  ];

  buildCommand = ''
    mkdir -p $out

    ln -s ${components.docs} $out/docs

    mkdir -p $out/bin
    cp ${components.run-playos-in-vm} $out/bin/run-playos-in-vm
    chmod +x $out/bin/run-playos-in-vm

    # Certificate used to verify update bundles
    ln -s ${updateCert} $out/cert.pem
  ''

  + lib.optionalString buildLive ''
    ln -s ${components.live}/iso/playos-live-${components.version}.iso $out/playos-live-${components.version}.iso
  ''
  # Installer ISO image
  + lib.optionalString buildInstaller ''
    ln -s ${components.installer}/iso/playos-installer-${components.version}.iso $out/playos-installer-${components.version}.iso
  ''
  # RAUC bundle
  + lib.optionalString buildBundle ''
    ln -s ${components.unsignedRaucBundle} $out/playos-${components.version}-UNSIGNED.raucb
    cp ${components.deploy-playos-update} $out/bin/deploy-playos-update
    chmod +x $out/bin/deploy-playos-update
  '';

}
