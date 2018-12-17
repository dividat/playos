{ config, pkgs, lib, options, ... }:
with lib;
let
  cfg = config.systemPartition;
in
{
  options = {
    systemPartition = {
      device = mkOption {
        default = null;
        example = "/dev/sda";
        type = types.string;
        description = "Location of the device.";
      };

      fsType = mkOption {
        default = "auto";
        example = "ext3";
        type = types.string;
        description = "Type of the file system.";
      };

      options = mkOption {
        default = [ "ro" ];
        example = [ "data=journal" ];
        description = "Options used to mount the file system.";
        type = types.listOf types.string;
      };

    };
  };

  config = {
    fileSystems = {
      "/mnt/system" = {
        device = cfg.device;
        fsType = cfg.fsType;
        options = cfg.options;
        neededForBoot = true;
      };
      "/nix/store" = {
        # Bind mount nix store
        device = "/mnt/system/nix/store";
        options = [ "bind" ];
      };
    };

    boot.initrd.postMountCommands = ''
      # Link the stage-2 init to /, so that stage-1 can find it
      cd $targetRoot
      ln -s mnt/system/init init
      cd /
    '';
  };
}
