# This is the toplevel module for all PlayOS related functionalities.

# Things that are injected into the system
{pkgs, version, kioskUrl, safeProductName, fullProductName, greeting, playos-controller}:


{config, lib, ...}:
with lib;
{
  imports = [
    (import ./networking.nix { hostName = safeProductName; inherit lib pkgs config; })
    ./hardening.nix
    ./localization.nix
    ./remote-maintenance.nix
    ./self-update
    ./system-partition.nix
    ./volatile-root.nix
    ./compatibility
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

    # Start controller
    systemd.services.playos-controller = {
      description = "PlayOS Controller";
      serviceConfig = {
        ExecStart = "${playos-controller}/bin/playos-controller";
        User = "root";
        RestartSec = "10s";
        Restart = "always";
        ExecStartPre = "-${pkgs.writeShellScript "clear-state" ''
            rm -rf /var/lib/playos-controller/*
            rm -rf /var/lib/playos-controller/.*
        ''}";
        StateDirectory = "playos-controller";
      };
      wantedBy = [ "multi-user.target" ];
      requires = [ "connman.service" ];
      after = [ "rauc.service" "connman.service" ];
    };

    # Use the persistent partition for storing controller state only to avoid
    # storing the RAUC bundles in memory (tmpfs)
    playos.storage.persistentFolders."/var/lib/playos-controller" = {
      mode = "0755";
      user = "root";
      group = "root";
    };


  };
}
