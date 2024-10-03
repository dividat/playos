{ config, pkgs, lib, ... }:
let
  cfg = config.playos.storage;
  cfgPart = cfg.persistentDataPartition;
  # /mnt/data -> "mnt-data.mount"
  pathToSystemdMountUnit = path:
      (builtins.replaceStrings ["/"] ["-"] (lib.strings.removePrefix "/" path))
      + ".mount";
in
# a "unit test"
assert (pathToSystemdMountUnit "/mnt/data" == "mnt-data.mount");
with lib;
{
  options = {
    playos.storage = {
      persistentDataPartition = {
        device = mkOption {
          default = null;
          example = "/dev/sda";
          type = types.nullOr types.str;
        };

        mountPath = mkOption {
          default = "/mnt/data";
          type = types.path;
          description = ''
            Path where the `persistentDataPartition` will be mounted.
            Note: used both for the partition and as a prefix of
            `playos.storage.persistentFolders`.
          '';
        };

        fsType = mkOption {
          default = "auto";
          example = "ext3";
          type = types.str;
          description = "Type of the file system.";
        };

        options = mkOption {
          default = [ "defaults" ];
          example = [ "data=journal" ];
          description = "Options used to mount the file system.";
          type = types.listOf types.str;
        };

      };

      persistentFolders = mkOption {
        default = {};
        description = ''Persistent folders.'';
        # TODO: use submodule (see for example nixos/modules/system/etc/etc.nix)
        type = types.attrs;
      };
    };

  };

  config = {
    fileSystems =
      (lib.mapAttrs
      (n: config: {
        device = "${cfgPart.mountPath}${n}";
        options = [ "bind" "noexec" ];
      })
      cfg.persistentFolders) //
      {
        # Force to override if other root has been configured
        "/" = mkForce {
          fsType = "tmpfs";
          options = [ "mode=0755" "noexec" ];
        };
        "${cfgPart.mountPath}" = {
          inherit (cfgPart) device fsType;
	  options = cfgPart.options ++ [ "noexec" ];
          # mount during stage-1, so that directories can be initialized
          neededForBoot = true;
        };
    };

    system.activationScripts = {
    ensurePersistentFoldersExist = lib.stringAfter [ "groups" ] (
      lib.concatStringsSep "\n"
        (lib.mapAttrsToList (n: config: ''
          mkdir -p ${cfgPart.mountPath}${n}
          chmod -R ${config.mode} ${cfgPart.mountPath}${n}
          chown ${config.user}:${config.group} ${cfgPart.mountPath}${n}
        '') cfg.persistentFolders));
    };

    # Note: this service executes its payload when STOPPED,
    # so the conditions are "in reverse" - don't get confused!
    systemd.services."playos-wipe-persistent-data" = {
      # Disable the service on boot. Note that `enable = false` would mask the service,
      # which prevents it from being run entirely and is not what we want.
      wantedBy = mkForce [ ];

      # Ensure this service is stopped AFTER the persistent data partition is unmounted
      before = [
        (pathToSystemdMountUnit cfgPart.mountPath)
      ];

      # Ensure /nix/store is still mounted while this unit is being stopped
      after = [
        "nix-store.mount"
      ];

      # Specifies that this unit should fail if /nix/store is not available,
      # without attempting to re-mount it.
      requisite = [
        "nix-store.mount"
      ];

      unitConfig = {
        DefaultDependencies = "no";
      };

      serviceConfig = {
        User = "root";
        Group = "root";
        Type = "oneshot";
        RemainAfterExit = "yes";
        TimeoutStopSec = "2min"; # ensure it always has enough time to complete
        ExecStart = pkgs.writeShellScript "start-wipe" ''
            echo "Unit activated, persistent data will be wiped on shutdown or reboot!"
        '';
        ExecStop =
            # Not attempting to be generic here because it would require
            # handling many cases (tmpfs, auto) and ensure appropriate (mkfs.X)
            # binaries are available (which live in a jungle of packages).
            #
            # Format (ext4) and label ('data') match hard-coded values in
            # install and rescue scripts.
            pkgs.writeShellScript "wipe-data" ''
                ${pkgs.e2fsprogs}/bin/mkfs.ext4 -v -F -L data ${cfgPart.device}
            '';
      };
    };
  };

}
