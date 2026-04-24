{ pkgs, grubCfg, rescueSystem, systemMetadata, systemImage, squashfsCompressionOpts }:
let
  # Installation script
  install-playos = pkgs.callPackage ./install-playos {
    inherit grubCfg rescueSystem;
    inherit systemImage systemMetadata;
  };

  configuration = (import ./configuration.nix) {
    inherit install-playos squashfsCompressionOpts;
    inherit systemMetadata;
  };
in
{

  inherit install-playos;

  isoImage = (pkgs.nixos {
    configuration = {
      imports = [ configuration ];
    };
    system = "x86_64-linux";
  }).config.system.build.isoImage;
}
