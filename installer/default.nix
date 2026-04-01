# TODO: rename this to "skeleton" that exposes several components:
# - [ ] skeleton configuration params (partition labels, hard-coded paths like /boot/status.ini)
# - [x] the installer script (for e2e and release validation tests)
# - [x] the rescueSystem (for e2e and release validation tests)
# - [x] the installer ISO
{ squashfsCompressionOpts
, systemImage
# TODO: combine this into a single systemMetadata attrset that is defined in the top-level default.nix
, safeProductName, fullProductName, kioskUrl, updateUrl, version
}:
let
  # versioned manually, this needs to be bumped if installer/ changes
  skeletonVersion = "0.1.0";

  pkgs = import ./pkgs;

  systemMetadata = {
    inherit safeProductName fullProductName kioskUrl updateUrl version;
  };

  # Rescue system
  rescueSystem = pkgs.callPackage ./bootloader/rescue {
    inherit (pkgs) nixos;
    inherit squashfsCompressionOpts;
    inherit systemMetadata;
  };


  # Installation script
  install-playos = pkgs.callPackage ./install-playos {
    grubCfg = ./bootloader/grub.cfg;
    inherit rescueSystem;
    inherit systemImage systemMetadata;
  };

  configuration = (import ./configuration.nix) {
    inherit install-playos squashfsCompressionOpts;
    inherit systemMetadata skeletonVersion;
  };


  isoImage = (pkgs.nixos {
    configuration = {
      imports = [ configuration ];
    };
    system = "x86_64-linux";
  }).config.system.build.isoImage;
in
{
  inherit install-playos isoImage rescueSystem;
}
