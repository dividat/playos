{ config, pkgs, lib, ... }:
let
  cfg = config.volatileRoot;
in
with lib;
{
  options = {
    volatileRoot = {
      persistentDataPartition = {
        device = mkOption {
          default = null;
          example = "/dev/sda";
          type = types.string;
        };

        fsType = mkOption {
          default = "auto";
          example = "ext3";
          type = types.string;
          description = "Type of the file system.";
        };

        options = mkOption {
          default = [ "defaults" ];
          example = [ "data=journal" ];
          description = "Options used to mount the file system.";
          type = types.listOf types.string;
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
        "/" = {
          fsType = "tmpfs";
          options = [ "mode=0755" ];
        };
        "/mnt/data" = {
          inherit (cfg.persistentDataPartition) device fsType options;
          # mount during stage-1, so that directories can be initialized
          neededForBoot = true;
        };
    };

    # TODO: allow user and group of persistent folder to be defined
    system.activationScripts = {
      ensurePersistentFoldersExist = lib.concatStringsSep "\n"
        (lib.mapAttrsToList (n: config: ''
          mkdir -p /mnt/data${n}
          chmod -R ${config.mode} /mnt/data${n}
        '') cfg.persistentFolders);
    };

  };

}
