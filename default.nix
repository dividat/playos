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

{
  ###### Configuration that is passed into the build system #######

  # Certificate used for verification of update bundles
  updateCert ? pkgs.lib.warn "Using dummy update certificate. Build artifacts can only be used for local development." ./pki/dummy/cert.pem

  # url from where updates should be fetched
, updateUrl ? "http://localhost:9000/"
, deployUrl ? "s3://dist-test.dividat.ch/releases/playos/test/"

  # url where kiosk points
, kioskUrl ? "https://play.dividat.com"

  ##### Allow disabling the build of unused artifacts when developing/testing #####
, buildInstaller ? true
, buildBundle ? true
, buildDisk ? true
}:

with pkgs;
let

  # lib.makeScope returns consistent set of packages that depend on each other (and is my new favorite nixpkgs trick)
  components = lib.makeScope newScope (self: with self; {

    # Set version
    version = "2019.2.6-beta";

    inherit updateUrl deployUrl kioskUrl;

    # Documentations
    docs = callPackage ./docs {};

    # Certificate used for verification of update bundles
    updateCert = copyPathToStore updateCert;

    # NixOS system toplevel
    systemToplevel = callPackage ./system {};

    # Controller
    playos-controller = callPackage ./controller {};

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
    testingToplevel = callPackage ./testing/system {};

    # Disk image containing pre-installed system
    disk = if buildDisk then callPackage ./testing/disk {} else null;

    # Script for spinning up VMs
    run-playos-in-vm = callPackage ./testing/run-playos-in-vm {};

  });

in

stdenv.mkDerivation {
  name = "playos-${components.version}";

  buildInputs = [
    rauc
    (python36.withPackages(ps: with ps; [pyparted]))
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
