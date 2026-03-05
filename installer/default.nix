# Build NixOS system
{ squashfsCompressionOpts
, systemImage
# TODO: combine this into a single systemMetadata attrset that is defined in the top-level default.nix
, safeProductName, fullProductName, kioskUrl, updateUrl, version
}:
let
  nixpkgs = builtins.fetchTarball {
    # release-24.11 2025-02-10
    url = "https://github.com/NixOS/nixpkgs/archive/edd84e9bffdf1c0ceba05c0d868356f28a1eb7de.tar.gz";
    sha256 = "1gb61gahkq74hqiw8kbr9j0qwf2wlwnsvhb7z68zhm8wa27grqr0";
  };

  overlay =
    self: super: {
      rauc = (import ./rauc) super;
    };

  pkgs = import nixpkgs { overlays = [ overlay ]; };

  nixos = import "${nixpkgs}/nixos";

  systemMetadata = {
    inherit safeProductName fullProductName kioskUrl updateUrl version;
  };

  # Rescue system
  rescueSystem = pkgs.callPackage ./bootloader/rescue {
    inherit nixos squashfsCompressionOpts;
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
    inherit systemMetadata;
  };


  isoImage = (nixos {
    configuration = {
      imports = [ configuration ];
    };
    system = "x86_64-linux";
  }).config.system.build.isoImage;
in
{
  inherit install-playos isoImage;
}
