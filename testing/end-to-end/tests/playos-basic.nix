{pkgs, disk, overlayPath, ...}:
pkgs.testers.runNixOSTest {
  name = "Built PlayOS is functional";

  nodes = {
    playos = { config, lib, pkgs, ... }:
    {
      imports = [
        (import ../virtualisation-config.nix { inherit overlayPath; })
      ];
    };
  };

  extraPythonPackages = ps: [ps.types-colorama];

  testScript = ''
    ${builtins.readFile ../test-script-helpers.py}
    import json

    create_overlay("${disk}", "${overlayPath}")

    playos.start(allow_reboot=True)

    with TestCase("PlayOS disk boots"):
        playos.wait_for_unit('multi-user.target')
        playos.wait_for_x()

    with TestCase("PlayOS services are runnning"):
        playos.wait_for_unit('dividat-driver.service')
        playos.wait_for_unit('playos-controller.service')
        playos.wait_for_unit('playos-status.service')

    # TODO: add test to check that we can log into play.dividat.com
    # TODO: add test to check that controller GUI works

    with TestCase("Booted from system.a") as t:
        rauc_status = json.loads(playos.succeed("rauc status --output-format=json"))
        t.assertEqual(
            rauc_status['booted'],
            "a"
        )

    # mark other (b) slot as active and try to reboot into it
    playos.succeed('busctl call de.pengutronix.rauc / de.pengutronix.rauc.Installer Mark ss "active" "other"')

    # NOTE: 'systemctl reboot' fails because of some bug in test-driver
    # - it seems to keep consuming console text after the reboot
    playos.shutdown()
    playos.start()

    # it should now boot without requiring to select anything in GRUB
    playos.wait_for_x()

    with TestCase("Booted into other slot") as t:
        rauc_status = json.loads(playos.succeed("rauc status --output-format=json"))
        t.assertEqual(
            rauc_status['booted'],
            "b",
            "Did not boot from other (i.e. system.b) slot"
        )
  '';
}
