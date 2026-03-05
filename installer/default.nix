# Build NixOS system
{ systemImage
, version, safeProductName, fullProductName, greeting
, kioskUrl, updateUrl
, squashfsCompressionOpts
}:
let
  nixpkgs = builtins.fetchTarball {
    # release-24.11 2025-02-10
    url = "https://github.com/NixOS/nixpkgs/archive/edd84e9bffdf1c0ceba05c0d868356f28a1eb7de.tar.gz";
    sha256 = "1gb61gahkq74hqiw8kbr9j0qwf2wlwnsvhb7z68zhm8wa27grqr0";
  };

  pkgs = import nixpkgs { };

  nixos = import "${nixpkgs}/nixos";

  # Rescue system
  rescueSystem = pkgs.callPackage ../bootloader/rescue {
    inherit nixos safeProductName fullProductName squashfsCompressionOpts;
  };

  # Installation script
  install-playos = pkgs.callPackage ./install-playos {
    grubCfg = ../bootloader/grub.cfg;
    inherit kioskUrl updateUrl rescueSystem systemImage version;
  };

  configuration = (import ./configuration.nix) {
    inherit install-playos version safeProductName fullProductName greeting squashfsCompressionOpts;
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
