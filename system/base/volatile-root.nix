{ config, pkgs, lib, ... }:
let
  cfg = config.playos.storage;
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
        device = "/mnt/data${n}";
        options = [ "bind" ];
      })
      cfg.persistentFolders) //
      {
        # Force to override if other root has been configured
        "/" = mkForce {
          fsType = "tmpfs";
          options = [ "mode=0755" ];
        };
        "/mnt/data" = {
          inherit (cfg.persistentDataPartition) device fsType options;
          # mount during stage-1, so that directories can be initialized
          neededForBoot = true;
        };
    };

    system.activationScripts = {
    ensurePersistentFoldersExist = lib.stringAfter [ "groups" ] (
      lib.concatStringsSep "\n"
        (lib.mapAttrsToList (n: config: ''
          mkdir -p /mnt/data${n}
          chmod -R ${config.mode} /mnt/data${n}
          chown ${config.user}:${config.group} /mnt/data${n}
        '') cfg.persistentFolders));
    };

  };

}
