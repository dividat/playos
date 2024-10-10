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
, buildTest ? false
}:

let

  application = import applicationPath;

  pkgs = import ./pkgs (with application; {
    applicationOverlays = application.overlays;
  });

  # lib.makeScope returns consistent set of packages that depend on each other
  mkComponents = { application, rescueSystemOpts ? {} }: (with pkgs; lib.makeScope newScope (self: with self; {

    inherit updateUrl deployUrl kioskUrl;
    inherit (application) version safeProductName fullProductName;

    greeting = lib.attrsets.attrByPath [ "greeting" ] (label: label) application;

    # Controller
    playos-controller = import ./controller {
      pkgs = pkgs;
      version = version;
      bundleName = safeProductName;
      updateUrl = updateUrl;
      kioskUrl = kioskUrl;
    };

    # Documentations
    docs = callPackage ./docs {};

    # Certificate used for verification of update bundles
    updateCert = copyPathToStore updateCert;

    # System image as used in full installation
    systemImage = callPackage ./system-image {
        application = application;
    };

    # USB live system
    live = callPackage ./live { application = application; };

    # Installation script
    install-playos = callPackage ./installer/install-playos {
      grubCfg = ./bootloader/grub.cfg;
    };

    # Rescue system
    rescueSystem = callPackage ./bootloader/rescue {
        application = application;
    } // rescueSystemOpts;

    # Installer ISO image
    installer = callPackage ./installer {};

    # Script to deploy updates
    deploy-update = callPackage ./deployment/deploy-update { application = application; };

    # RAUC bundle
    unsignedRaucBundle = callPackage ./rauc-bundle {};

    # NixOS system toplevel with test machinery
    # used for run-in-vm (without --disk) and testing/integration
    testingToplevel = callPackage ./testing/system { application = application; };

    # Disk image containing pre-installed system
    disk = if buildDisk then callPackage ./testing/disk {} else null;

    # Script for spinning up VMs
    run-in-vm = callPackage ./testing/run-in-vm {};

    # End-to-end tests that depend on on `disk`
    tests = (if ! buildDisk then
                throw "buildDisk is required for running end-to-end tests"
            else
                callPackage ./testing/end-to-end {});
  }));

  components = mkComponents { inherit application; };

  testComponents = mkComponents {
    application = {
      inherit (application) safeProductName fullProductName greeting overlays;
      version = "${application.version}-TEST";
      module = {
        imports = [
          application.module
          ./testing/end-to-end/profile.nix
        ];
      };
    };
    rescueSystemOpts = { squashfsCompressionOpts = "-no-compression"; };
  };

in

with pkgs; stdenv.mkDerivation {
  name = "${components.safeProductName}-${components.version}";

  buildInputs = [
    rauc
    (python3.withPackages(ps: with ps; [pyparted]))
    components.install-playos
  ];

  buildCommand = ''
    mkdir -p $out

    ln -s ${components.docs} $out/docs

    mkdir -p $out/bin
    cp ${components.run-in-vm} $out/bin/run-in-vm
    chmod +x $out/bin/run-in-vm

    # Certificate used to verify update bundles
    ln -s ${updateCert} $out/cert.pem
  ''

  + lib.optionalString buildLive ''
    ln -s ${components.live}/iso/${components.safeProductName}-live-${components.version}.iso $out/${components.safeProductName}-live-${components.version}.iso
  ''
  # Installer ISO image
  + lib.optionalString buildInstaller ''
    ln -s ${components.installer}/iso/${components.safeProductName}-installer-${components.version}.iso $out/${components.safeProductName}-installer-${components.version}.iso
  ''
  # RAUC bundle
  + lib.optionalString buildBundle ''
    ln -s ${components.unsignedRaucBundle} $out/${components.safeProductName}-${components.version}-UNSIGNED.raucb
    cp ${components.deploy-update} $out/bin/deploy-update
    chmod +x $out/bin/deploy-update
  ''
  # Tests
  + lib.optionalString buildTest ''
    ln -s ${testComponents.tests.interactive-tests} $out/tests
  '';

  passthru.tests = lib.optionalAttrs buildTest {
    end-to-end = testComponents.tests.run-tests;
  };
}
