# This is the toplevel module for all PlayOS related functionalities.

# Things that are injected into the system
{pkgs, version, kioskUrl, safeProductName, fullProductName, greeting, playos-controller}:


{config, lib, ...}:
with lib;
{
  imports = [
    (import ./networking.nix { hostName = safeProductName; inherit lib pkgs config; })
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
    nixpkgs.pkgs = pkgs;

    # Custom label when identifying OS
    system.nixos.label = "${safeProductName}-${version}";

    # disable installation of bootloader
    boot.loader.grub.enable = false;

    # disable installation of inaccessible documentation
    documentation.enable = false;

    playos = { inherit version kioskUrl; };

    # 'Welcome Screen'
    services.getty = {
      greetingLine = greeting "${fullProductName} (${version})";
      helpLine = "";
    };

    # Start controller
    systemd.services.playos-controller = {
      description = "PlayOS Controller";
      serviceConfig = {
        ExecStart = [ "${playos-controller}/bin/playos-controller" ];
        User = "root";
        RestartSec = "10s";
        Restart = "always";
      };
      wantedBy = [ "multi-user.target" ];
      requires = [ "connman.service" ];
      after = [ "rauc.service" "connman.service" ];
    };

  };
}
