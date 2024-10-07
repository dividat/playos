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
}
