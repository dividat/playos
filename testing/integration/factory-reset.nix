let
  pkgs = import ../../pkgs { };
  # images are created in the testScript
  bootVolumeImage = "/tmp/factory-reset-boot-volume.raw";
  persistentVolumeImage = "/tmp/factory-reset-persistent-volume.raw";
in
with pkgs.lib;
pkgs.testers.runNixOSTest {
  name = "Persistent data partition wipe (factory reset) works";

  nodes = {
    playos = { config, ... }: {
      imports = [
        ../../base/volatile-root.nix
      ];

      config = {
        virtualisation.qemu.options = [
            "-hda" bootVolumeImage       # /dev/sda
            "-hdb" persistentVolumeImage # /dev/sdb
        ];

        # Needed to avoid virtualisation overriding volatile-root.nix fileSystem
        # configuration
        virtualisation.fileSystems = mkForce { };
        virtualisation.writableStore = false;
        virtualisation.diskImage = null;
        fileSystems = {
            # this is normally set up automatically by qemu-vm.nix but
            # need to do it manually due to `virtualisation.fileSystems = {}`
            "/nix/store" = {
              device = "nix-store";
              fsType = "9p";
              neededForBoot = true;
              options = [
                "trans=virtio" "version=9p2000.L"
                "msize=${toString config.virtualisation.msize}"
                "cache=loose"
              ];
            };

            "/boot" = {
              device = "/dev/disk/by-label/ESP";
            };
        };
        playos.storage = {
          persistentDataPartition = {
            device = "/dev/disk/by-label/data";
          };
        };
      };
    };
  };

  extraPythonPackages = ps: [
    ps.colorama
    ps.types-colorama
  ];

  testScript = ''
${builtins.readFile ../helpers/nixos-test-script-helpers.py}

# ==== Setup: create disk images for /boot and /mnt/data

def create_qemu_disk_image(path):
    subprocess.run(["rm", "-f", path])

    subprocess.run(['qemu-img',
        'create', '-f', 'raw', path, "10M"],
        check=True
    )

boot_volume_image = "${bootVolumeImage}"
persistent_volume_image = "${persistentVolumeImage}"

create_qemu_disk_image(boot_volume_image)

subprocess.run(["${pkgs.dosfstools}/bin/mkfs.vfat",
    "-n", "ESP", boot_volume_image],
    check=True
)

create_qemu_disk_image(persistent_volume_image)

subprocess.run(["${pkgs.e2fsprogs}/bin/mkfs.ext4",
    "-L", "data", persistent_volume_image],
    check=True
)

# ==== Test scenario
# Note: scenario is re-used in e2e tests as well

${builtins.readFile ./factory-reset-scenario.py}
'';
}
