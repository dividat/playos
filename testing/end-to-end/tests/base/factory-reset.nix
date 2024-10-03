{pkgs, disk, overlayPath, ...}:
pkgs.testers.runNixOSTest {
  name = "Factory reset works";

  nodes = {
    playos = { config, lib, pkgs, ... }:
    {
      imports = [
        (import ../../virtualisation-config.nix { inherit overlayPath; })
      ];
    };
  };

  extraPythonPackages = ps: [
    ps.colorama
    ps.types-colorama
  ];

  testScript = ''
${builtins.readFile ../../../helpers/nixos-test-script-helpers.py}
create_overlay("${disk}", "${overlayPath}")

playos.start(allow_reboot=True)

with TestPrecondition("Persistent data is mounted"):
    playos.wait_for_unit('mnt-data.mount')

with TestCase("Persistent data remains after reboot"):
    playos.succeed("echo TEST_DATA > /mnt/data/persist-me")
    playos.shutdown()
    playos.start(allow_reboot=True)
    playos.wait_for_unit('mnt-data.mount')
    playos.succeed("grep TEST_DATA /mnt/data/persist-me")

with TestCase("Persistent data is wiped if factory reset is triggered"):
    playos.succeed("systemctl start playos-wipe-persistent-data.service")
    playos.shutdown()
    playos.start()
    playos.wait_for_unit('mnt-data.mount')
    playos.succeed("test ! -f /mnt/data/persist-me")
'';

}
