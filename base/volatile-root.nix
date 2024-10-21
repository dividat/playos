{ config, pkgs, lib, ... }:
let
  cfg = config.playos.storage;
  cfgPart = cfg.persistentDataPartition;
  magicWipeFile = ".WIPE_PERSISTENT_DATA";
  hasBootFs = config.fileSystems ? "/boot";
  bootFsCfg = config.fileSystems."/boot";
  supportedBootFsType = if (bootFsCfg.fsType == "auto") then "vfat" else bootFsCfg.fsType;
in
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
    warnings =
        if (! hasBootFs) then
            [ "No /boot filesystem configured, wiping will not work" ]
        else if (bootFsCfg.fsType == "auto") then
            [ "/boot fstype is auto, filesystem might not be mountable in stage-1" ]
        else
            [ ]
    ;
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

    # make sure boot fstype (with fallback to at least vfat) support is in initrd
    boot.supportedFilesystems = lib.mkIf hasBootFs [ supportedBootFsType ];
    boot.initrd.supportedFilesystems = lib.mkIf hasBootFs [ supportedBootFsType ];

    # Check if /boot contains magicWipeFile and reformat persistent data
    boot.initrd.postDeviceCommands = lib.mkIf hasBootFs ''
        # === Create temp mount point for /boot
        tmpBootMountPoint="/tmp/boot"
        mkdir -p $tmpBootMountPoint

        # === Resolve /boot's file system type
        # Since busybox mount does not deal with `auto` well in initrd, copied
        # from nixos stage-1-init.sh
        fsType="${bootFsCfg.fsType}"
        if [ "$fsType" = auto ]; then
            fsType=$(blkid -o value -s TYPE "${bootFsCfg.device}")
            if [ -z "$fsType" ]; then fsType=auto; fi
        fi

        # === Mount /boot on $tmpBootMountPoint
        mount -t "$fsType" ${bootFsCfg.device} $tmpBootMountPoint

        # === Wipe persistent data if magicWipeFile is present
        if [ -f "$tmpBootMountPoint/${magicWipeFile}" ]; then
            # fstype and label hard-coded, same as in install and rescue scripts
            ${pkgs.e2fsprogs}/bin/mkfs.ext4 -L data ${cfgPart.device}
            rm -f $tmpBootMountPoint/${magicWipeFile}
        fi

        # === Cleanup
        umount $tmpBootMountPoint
        rmdir $tmpBootMountPoint
    '';

    system.activationScripts = {
    ensurePersistentFoldersExist = lib.stringAfter [ "groups" ] (
      lib.concatStringsSep "\n"
        (lib.mapAttrsToList (n: config: ''
          mkdir -p ${cfgPart.mountPath}${n}
          chmod -R ${config.mode} ${cfgPart.mountPath}${n}
          chown ${config.user}:${config.group} ${cfgPart.mountPath}${n}
        '') cfg.persistentFolders));
    };

    # Note: this service always exists, but will fail if /boot filesystem is not
    # configured
    systemd.services."playos-wipe-persistent-data" = {
      # Disable the service on boot. Note that `enable = false` would mask the service,
      # which prevents it from being run entirely and is not what we want.
      wantedBy = mkForce [ ];

      requires = [
        "boot.mount"
      ];

      serviceConfig = {
        User = "root";
        Group = "root";
        Type = "oneshot";
        RemainAfterExit = "yes";
        ExecStart = pkgs.writeShellScript "enable-wipe" ''
            touch /boot/${magicWipeFile}
            echo "Wipe activated, persistent data will be wiped on next boot!"
        '';
      };
    };
  };

}
