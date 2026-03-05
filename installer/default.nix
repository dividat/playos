# Build NixOS system
{ config, lib, pkgs
, systemImage
, version, safeProductName, fullProductName, greeting
, kioskUrl, updateUrl
, squashfsCompressionOpts
}:
let
  nixos = pkgs.importFromNixos "";

  # Rescue system
  rescueSystem = pkgs.callPackage ../bootloader/rescue {
    inherit safeProductName fullProductName squashfsCompressionOpts;
  };

  # Installation script
  install-playos = pkgs.callPackage ./install-playos {
    grubCfg = ../bootloader/grub.cfg;
    inherit kioskUrl updateUrl rescueSystem systemImage version;
  };

  configuration = (import ./configuration.nix) {
    inherit config pkgs lib install-playos version safeProductName fullProductName greeting squashfsCompressionOpts;
  };


  isoImage = (nixos {
    inherit configuration;
    system = "x86_64-linux";
  }).config.system.build.isoImage;
in
{
  inherit install-playos isoImage;
}
