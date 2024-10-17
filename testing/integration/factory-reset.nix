let
  pkgs = import ../../pkgs { };
  # images are created in the testScript
  bootVolumeImage = "/tmp/factory-reset-boot-volume.raw";
  persistentVolumeImage = "/tmp/factory-reset-persistent-volume.raw";
in
with pkgs.lib;
pkgs.testers.runNixOSTest {
  name = "Controller system calls";

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
                device = "/dev/sda";
            };
        };
        playos.storage = {
          persistentDataPartition = {
            device = "/dev/sdb";
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

def create_ext4_image(path):
    subprocess.run(["rm", "-f", path])

    subprocess.run(['qemu-img',
        'create', '-f', 'raw', path, "10M"],
        check=True
    )

    subprocess.run(["${pkgs.e2fsprogs}/bin/mkfs.ext4",
        "-L", "data", path],
        check=True
    )

persistent_volume_image = "${persistentVolumeImage}"
boot_volume_image = "${bootVolumeImage}"

create_ext4_image(persistent_volume_image)
create_ext4_image(boot_volume_image)

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
