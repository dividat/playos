# Test machinery
{lib, pkgs, ...}:

{
  imports = [
    (pkgs.importFromNixos "modules/profiles/qemu-guest.nix")
    (pkgs.importFromNixos "modules/testing/test-instrumentation.nix")
  ];

  config = {
    systemPartition = lib.mkForce {
      device = "system";
      fsType = "9p";
      options = [ "trans=virtio" "version=9p2000.L" "cache=loose" ];
    };

    volatileRoot.persistentDataPartition = lib.mkForce {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [ "mode=0755" ];
    };

    fileSystems."/boot" = lib.mkForce {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [ "mode=0755" ];
    };

    networking.hostName = lib.mkForce "playos-test";

  };

}
