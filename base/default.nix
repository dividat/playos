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
    ./denixify.nix
    ./hardening.nix
    ./localization.nix
    ./remote-maintenance.nix
    ./self-update
    ./system-partition.nix
    ./volatile-root.nix
    ./compatibility
    ./unsupervised.nix
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

    playos = { inherit version kioskUrl; };

    # Make a PlayOS-specific os-release file
    # https://www.freedesktop.org/software/systemd/man/latest/os-release.html
    environment.etc."os-release".text = lib.mkForce ''
      ID=${safeProductName}
      ID_LIKE="nixos"
      NAME="${fullProductName}"
      PRETTY_NAME="${fullProductName} ${version} (NixOS ${config.system.nixos.release} ${config.system.nixos.codeName})"
      VERSION="${version}"
      VERSION_ID="${version}"
      HOME_URL="https://github.com/dividat/playos"
      BUG_REPORT_URL="https://github.com/dividat/playos/issues"
    '';

    # 'Welcome Screen'
    services.getty = {
      greetingLine = greeting "${fullProductName} (${version})";
    };

  };
}
