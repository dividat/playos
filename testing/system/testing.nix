# Test machinery
{lib, pkgs, config, modulesPath, ...}:

{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
    "${modulesPath}/testing/test-instrumentation.nix"
    ./testing-wifi.nix # comment out to disable simulated wifi APs
    ./fake-rauc-boot.nix # comment out to disable RAUC/self-update
    ./stub-update-server.nix # comment out to disable stub-update-server
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

    # run a little bit faster for easier testing
    playos.networking.watchdog = {
        enable = true;
        checkURLs = [ config.playos.kioskUrl ];
        maxNumFailures = 3;
        checkInterval = 10;
        settingChangeDelay = 15;
    };

  };

}
