{ overlayPath, ... }:
{
    config = {
        # Kinda abusing the NixOS testing infra here, because
        # there is no other interface for creating test VMs/nodes.
        #
        # Instead of specifying/building a NixOS system, here we
        # pass an already built disk image, so the options below are mainly
        # for _preventing_ qemu-vm.nix from passing any unnecessary flags to
        # QEMU.
        #
        # Due to this, certain NixOS test driver features might not be
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
            "-device i6300esb,id=watchdog0" "-action watchdog=reset"
            # HACK: normally the `system.build.vm` derivation produces a start
            # script that creates a (temporary or overlay) filesystem image file
            # prior to launching a VM. Since it is not configurable to our
            # needs, we create the overlay image instead in the `testScript`,
            # so this path is a "forward reference" that does not exist.
            "-hda ${overlayPath}"
        ];
    };
}
