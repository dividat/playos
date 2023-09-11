# Test machinery
{lib, pkgs, ...}:

{
  imports = [
    (pkgs.importFromNixos "modules/profiles/qemu-guest.nix")
    (pkgs.importFromNixos "modules/testing/test-instrumentation.nix")
  ];

  config = {
    fileSystems."/boot" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [ "mode=0755" ];
    };
    playos.storage = {
      systemPartition = {
        enable = true;
        device = "system";
        fsType = "9p";
        options = [ "trans=virtio" "version=9p2000.L" "cache=loose" ];
      };

      persistentDataPartition = {
        device = "tmpfs";
        fsType = "tmpfs";
        options = [ "mode=0755" ];
      };
    };

    networking.hostName = lib.mkForce "playos-test";

  };

}
