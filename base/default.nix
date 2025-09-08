# This is the toplevel module for all PlayOS related functionalities.

# Things that are injected into the system
{pkgs, version, kioskUrl, safeProductName, fullProductName, greeting, playos-controller}:


{config, lib, ...}:
with lib;
{
  imports = [
    (import ./networking/default.nix { hostName = safeProductName; inherit lib pkgs config; })
    (import ./controller-service.nix { inherit config lib pkgs playos-controller; })
    ./networking/watchdog
    ./hardening.nix
    ./localization.nix
    ./remote-maintenance.nix
    ./self-update
    ./system-partition.nix
    ./volatile-root.nix
  ];

  options = {
    playos.version = mkOption {
      type = types.str;
      default = version;
    };

    playos.kioskUrl = mkOption {
      type = types.str;
    };
  };

  config = {
    # Use overlayed pkgs.
    nixpkgs.pkgs = lib.mkDefault pkgs;

    # Custom label when identifying OS
    system.nixos.label = "${safeProductName}-${version}";

    # disable installation of bootloader
    boot.loader.grub.enable = false;

    # disable inaccessible documentation
    documentation = {
      enable = false;
      doc.enable = false;
      info.enable = false;
      man.enable = false;
      nixos.enable = false;
    };

    playos = { inherit version kioskUrl; };

    # 'Welcome Screen'
    services.getty = {
      greetingLine = greeting "${fullProductName} (${version})";
    };

  };
}
