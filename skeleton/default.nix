# The PlayOS skeleton defines the immutable parts of an installed system
# and provides tools to perform the installation.
#
# It consists of:
# - the bootloader
# - the rescue system
# - the installer (script and ISO image)
#
# The installer also sets up various hard-coded configuration parts of the
# system: partition labels and sizes, GRUB config, RAUC slot paths and labels.
#
# The mutable "complement" of the skeleton is the updatable PlayOS runtime
# system as defined by `../system-image/`, which relies on the hard-coded
# configuration.
#
# The skeleton maintains a separate pin on nixpkgs, to ensure that the
# installed runtime software (e.g. GRUB) does not change and that tools which
# set up the system do it in an identical way (e.g. mkfs tools write the same
# metadata to the partition table) across PlayOS versions.
{ squashfsCompressionOpts
, systemImage
, safeProductName, fullProductName, kioskUrl, updateUrl, version
}:
let
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

  installer = pkgs.callPackage ./installer {
    inherit rescueSystem systemImage systemMetadata squashfsCompressionOpts;
  };


in
{
  inherit rescueSystem installer;
}
