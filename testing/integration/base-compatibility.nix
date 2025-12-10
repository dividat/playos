let
  pkgs = import ../../pkgs { };
in
pkgs.testers.runNixOSTest {
  name = "base compatibility";

  nodes = {
    machine = { config, pkgs, ... }: {
      imports = [ ../../base/compatibility ];

      environment.systemPackages = with pkgs; [ e2fsprogs ];

      systemd.services."test-service" = {
        path = with pkgs; [ e2fsprogs ];
        after = [ "local-fs.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig.Type = "oneshot";
        serviceConfig.RemainAfterExit = true;
        serviceConfig.ExecStart = pkgs.writeShellScript "format"
            ''
            truncate -s 100M /tmp/partition-service.img
            mkfs.ext4 /tmp/partition-service.img
            '';
      };
    };
  };

  extraPythonPackages = ps: [
    ps.colorama
    ps.types-colorama
  ];

  testScript = ''
    ${builtins.readFile ../helpers/nixos-test-script-helpers.py}
    BAD_EXT4_FEATURES = ["metadata_csum_seed", "orphan_file"]

    def check_for_bad_features(part_file, t):
        features = machine.succeed(
            f'tune2fs -l "{part_file}" | grep "Filesystem features"')

        for bad_opt in BAD_EXT4_FEATURES:
            t.assertNotIn(bad_opt, features,
                    f"ext4 was formatted with {bad_opt}")

    machine.start()

    machine.wait_for_unit("local-fs.target")

    with TestCase("compatibility options are honoured when running from a shell") as t:
        machine.succeed("truncate -s 100M /tmp/partition-shell.img")
        machine.succeed("mkfs.ext4 /tmp/partition-shell.img")
        check_for_bad_features("/tmp/partition-shell.img", t)

    with TestCase("compatibility options are honoured when running in a service") as t:
        machine.wait_for_unit("test-service.service")
        check_for_bad_features("/tmp/partition-service.img", t)
  '';
}
