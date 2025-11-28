{
  # Enable remote access to InfluxDB (port 18086). Build using
  # `nix-build --arg debug true -A driverInteractive` and then use
  # influx/Chronograf/Grafana to connect to `http://localhost:18086/`
  debug ? false,
}:
let
  pkgs = import ../../pkgs { };

  inherit (pkgs) lib;
in
pkgs.testers.runNixOSTest {
  name = "monitoring";

  nodes = {
    machine =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      {
        imports = [
          ../../base/monitoring.nix
        ];

        config = {
          virtualisation.forwardPorts = lib.optional debug {
            from = "host";
            host.port = 18086;
            guest.port = 8086;
          };

          networking.firewall.enable = lib.mkIf debug (lib.mkForce false);

          playos.monitoring.enable = true;

          # collect faster in here
          playos.monitoring.collectionIntervalSeconds = 2;

          # modify retetion policy to check configuration works
          playos.monitoring.localRetention = "6h"; # 1h is smallest possible
          playos.monitoring.localDbShard = "2h"; # 1h is smallest possible

          environment.systemPackages = [
            pkgs.influxdb
          ];
        };
      };
  };

  extraPythonPackages = ps: [
    ps.colorama
    ps.types-colorama
  ];

  testScript =
    { nodes }:
    let
      monCfg = nodes.machine.playos.monitoring;
      dbName = monCfg.localDbName;
    in
    ''
      ${builtins.readFile ../helpers/nixos-test-script-helpers.py}
      import csv

      ## CONSTANTS

      ## HELPERS

      def run_query(query, as_dict_reader=True):
          res = machine.succeed(
              f"influx -database ${dbName} -format csv -execute '{query}'"
          ).strip().split('\n')
          # there should be at least a header
          assert len(res) > 1, f"Query '{query}' returned no data?"
          if as_dict_reader:
            return csv.DictReader(res)
          else:
            return res


      ## TESTS

      machine.start()

      with TestCase("influxdb and telegraf are running"):
        machine.wait_for_unit("influxdb.service", timeout=10)
        machine.wait_for_unit("telegraf.service", timeout=10)

      with TestCase("Retention policy is setup") as t:
        results = list(run_query("SHOW RETENTION POLICIES"))
        t.assertEqual(len(results), 1,
          f"More than one retention policy found: {results}")

        policy = results[0]
        t.assertEqual(policy['name'], "${monCfg.localRetention}")
        t.assertTrue(policy['duration'].startswith("${monCfg.localRetention}"))
        t.assertTrue(policy['shardGroupDuration'].startswith("${monCfg.localDbShard}"))
        t.assertEqual(policy['default'], "true")

      sleep_duration = ${toString monCfg.collectionIntervalSeconds} * 3
      print(f"Sleeping for {sleep_duration} seconds to collect some metrics")
      time.sleep(sleep_duration)
      print("Restarting telegraf to force flush")
      machine.systemctl("restart telegraf.service")

      with TestCase("Metrics are received") as t:
        results = list(run_query("SELECT * FROM mem LIMIT 2"))
        t.assertGreater(len(results), 1, "Expected at least 2 rows")
        first_result = results[0]

        t.assertIn("free", first_result)
        t.assertIn("used", first_result)

      with TestCase("Metrics are tagged with machine-id") as t:
        machineId = machine.succeed("cat /etc/machine-id").strip()
        t.assertEqual(first_result['host'], f"playos-{machineId}")

      with TestCase("Unnecessary tags are dropped") as t:
        cpu_row = list(run_query("SELECT * FROM cpu LIMIT 1"))[0]
        t.assertNotIn("time_guest_nice", cpu_row)
        t.assertNotIn("usage_guest_nice", cpu_row)
    '';
}
