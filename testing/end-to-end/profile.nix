{pkgs, modulesPath, ...}:
{
    imports = [
      (modulesPath + "/profiles/qemu-guest.nix")
      (modulesPath + "/testing/test-instrumentation.nix")
    ];

    config = {
        # disable hardware-accelerated graphics, reduces image size vastly
        hardware.graphics.enable = false;

        # test-instrumentation.nix sets this in the boot as kernel param,
        # but since we are booting with a custom GRUB config it has no effect,
        # so instead we set this directly in journald
        services.journald.extraConfig =
        let
          qemu-common = pkgs.callPackage
            (pkgs.path + "/nixos/lib/qemu-common.nix") {};
        in
        ''
            TTYPath=/dev/${qemu-common.qemuSerialDevice}
        '';
    };
}
