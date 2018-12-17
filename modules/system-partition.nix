{ config, pkgs, lib, ... }:
{
  fileSystems = {
    "/mnt/system" = {
      # Mount root read-only at /system
      device = "/dev/root";
      options = [ "ro" ];
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
}
