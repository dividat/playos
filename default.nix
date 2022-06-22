{
  ###### Configuration that is passed into the build system #######

  # Certificate used for verification of update bundles
  updateCert ? (import <nixpkgs> {}).lib.warn "Using dummy update certificate. Build artifacts can only be used for local development." ./pki/dummy/cert.pem

  # url from where updates should be fetched
, updateUrl ? "http://localhost:9000/"
, deployUrl ? "s3://dist-test.dividat.ch/releases/playos/test/"

  # url where kiosk points
, kioskUrl ? "https://play.dividat.com"

  ##### Allow disabling the build of unused artifacts when developing/testing #####
, buildInstaller ? true
, buildBundle ? true
, buildDisk ? true
, buildLive ? true
}:

let
  version = "2022.4.0-VALIDATION.1";

  # List the virtual terminals that can be switched to from the Xserver
  activeVirtualTerminals = [ 7 8 ];

  pkgs = import ./pkgs { inherit version updateUrl kioskUrl activeVirtualTerminals; };

  # lib.makeScope returns consistent set of packages that depend on each other (and is my new favorite nixpkgs trick)
  components = with pkgs; lib.makeScope newScope (self: with self; {

    greeting = label: ''
                                         _
                                     , -"" "".
                                   ,'  ____  `.
                                 ,'  ,'    `.  `._
        (`.         _..--.._   ,'  ,'        \\    \\
       (`-.\\    .-""        ""'   /          (  d _b
      (`._  `-"" ,._             (            `-(   \\
      <_  `     (  <`<            \\              `-._\\
       <`-       (__< <           :                      ${label}
        (__        (_<_<          ;
    -----`------------------------------------------------------ ----------- ------- ----- --- -- -
    '';

    inherit updateUrl deployUrl kioskUrl version;

    # Documentations
    docs = callPackage ./docs {};

    # Certificate used for verification of update bundles
    updateCert = copyPathToStore updateCert;

    # NixOS system toplevel
    systemToplevel = callPackage ./system {};

    # USB live system
    live = callPackage ./live {};

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

with pkgs; stdenv.mkDerivation {
  name = "playos-${version}";

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
    ln -s ${components.live}/iso/playos-live-${version}.iso $out/playos-live-${version}.iso
  ''
  # Installer ISO image
  + lib.optionalString buildInstaller ''
    ln -s ${components.installer}/iso/playos-installer-${version}.iso $out/playos-installer-${version}.iso
  ''
  # RAUC bundle
  + lib.optionalString buildBundle ''
    ln -s ${components.unsignedRaucBundle} $out/playos-${version}-UNSIGNED.raucb
    cp ${components.deploy-playos-update} $out/bin/deploy-playos-update
    chmod +x $out/bin/deploy-playos-update
  '';

}
