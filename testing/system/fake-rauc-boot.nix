# This module sets up a boot partition and GRUB in a way that is sufficient
# to fool RAUC into thinking things are somewhat properly set up.
# Allows doing various tests without mocking out RAUC.
{ pkgs, config, options, ... }:
with pkgs;
with lib;
let
    bootFsConfig = {
        "/boot" = {
          device = "tmpfs";
          fsType = "tmpfs";
          options = [ "mode=0755" ];

          neededForBoot = true; # only to consolidate it with qemu-vm.nix
                                # creating an ad-hoc /boot directory during
                                # stage-1
        };
    };
in
{
    fileSystems = bootFsConfig;

    # this is needed for integration tests
    virtualisation = lib.optionalAttrs (options?virtualisation.fileSystems)
        { fileSystems = bootFsConfig; };

    boot.kernelParams = [
        "rauc.slot=a"
    ];
    boot.postBootCommands = ''
        mkdir -p /boot/grub
        ${pkgs.grub2_efi}/bin/grub-editenv - create
        ${pkgs.grub2_efi}/bin/grub-editenv - set 'ORDER="a b"'
        ${pkgs.grub2_efi}/bin/grub-editenv - set a_TRY=0
        ${pkgs.grub2_efi}/bin/grub-editenv - set a_OK=1
        ${pkgs.grub2_efi}/bin/grub-editenv - set b_TRY=0
        ${pkgs.grub2_efi}/bin/grub-editenv - set b_OK=1
        cat <<EOF > /boot/status.ini
            [slot.system.a]
            bundle.version=${config.playos.version}
            installed.timestamp=2024-10-16T05:36:25.460927
            installed.count=0
            activated.timestamp=2024-10-16T07:55:41Z
            activated.count=1

            [slot.system.b]
            bundle.version=${config.playos.version}
            installed.timestamp=2024-10-16T05:37:35.663552
            installed.count=0
        EOF
        '';

    playos.selfUpdate = {
      enable = true;
      updateCert = pkgs.writeText "dummy.pem"  "";
    };

}
