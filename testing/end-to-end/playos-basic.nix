{pkgs, qemu, disk, ...}:
let
    overlayPath = "/tmp/playos-test-disk-overlay.qcow2";
in
pkgs.testers.runNixOSTest {
  name = "Built PlayOS is functional";

  nodes = {
    playos = { config, lib, pkgs, ... }:
    {
      # TODO: extract this into a profile
      config = {
        # Kinda abusing the NixOS testing infra here, because
        # there is no other interface for creating test VMs/nodes.
        #
        # Instead of specifying/building a NixOS system, here we
        # pass an already built disk image, so the options below are mainly
        # for _preventing_ qemu-vm.nix from passing any unnecssary flags to
        # QEMU.
        #
        # Due to this, test driver features requiring
        # `virtualisation.sharedDirectories` (e.g. `copy_from_vm`) are not
        # functional.
        virtualisation.mountHostNixStore = false;
        virtualisation.useHostCerts = false;
        virtualisation.directBoot.enable = false;
        virtualisation.useEFIBoot = true;
        virtualisation.useBootLoader = false;
        virtualisation.diskImage = null;

        # good when debugging in interactive mode
        virtualisation.graphics = true;

        # give it a bit more resources
        virtualisation.memorySize = 2048;
        virtualisation.cores = 2;

        virtualisation.qemu.options = [
            "-enable-kvm"
            # HACK, see testScript
            "-hda ${overlayPath}"
        ];
      };
    };
  };

  extraPythonPackages = ps: [ps.types-colorama];

  testScript = ''
    ${builtins.readFile ./test-script-helpers.py}
    import json

    creater_overlay("${disk}", "${overlayPath}")

    playos.start(allow_reboot=True)

    with TestCase("PlayOS disk boots"):
        playos.wait_for_unit('multi-user.target')
        playos.wait_for_x()

    with TestCase("PlayOS services are runnning"):
        playos.wait_for_unit('dividat-driver.service')
        playos.wait_for_unit('playos-controller.service')
        playos.wait_for_unit('playos-status.service')

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
