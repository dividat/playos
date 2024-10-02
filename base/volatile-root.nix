{ config, pkgs, lib, ... }:
let
  cfg = config.playos.storage;
  cfgPart = cfg.persistentDataPartition;
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

  };

}
