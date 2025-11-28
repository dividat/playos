# Stress and "volume" testing of the monitoring setup.
#
# The test generates simulated data to backfill InfluxDB for the configured
# retention period and checks several invariants:

# - No cardinality explosion: the default metric collection (via Telegraf) is
#   ran to check that it produces series with cardinalities within expected
#   limits (for this stress test and in general)
# - Telegraf memory usage is within limits
# - Disk usage: after backfilling, stored InfluxDB data is within expeted limits
# - Memory usage: after backfilling and after InfluxDB completes compaction,
#   we check that it can reach a resting state with low memory usage.
#
# Note that the observed memory usage here is higher than what we expect in a
# production system, since:
# - Telegraf is collecting data at 1s intervals, 60x faster
# - Months of data for the whole retention period is generated in *minutes*

{
  # Enabling slowMode runs this test in a less stressful way by setting a
  # delay between batched writes. This makes the data generation last ~15
  # minutes (instead of ~1-2m). This is still 8000x faster than we will be
  # producing data, but gives enough time for InfluxDB to do house-cleaning
  # and shows a more realistic memory profile.
  slowMode ? false,

  # for (test) development - run through with tiny data and sleeps to check if
  # the test setup works
  speedrun ? false,

  # Enable remote access to InfluxDB (port 18086). Build using
  # `nix-build --arg debug true -A driverInteractive` and then use
  # influx/Chronograf/Grafana to connect to `http://localhost:18086/`
  debug ? false,
}:
let
  pkgs = import ../../pkgs { };

  inherit (pkgs) lib;

  # influxdb stress testing tool
  inch_tool = pkgs.buildGoModule rec {
    pname = "inch";
    name = "inch";

    vendorHash = "sha256-upbcZCZEqgp8QlbA1qihLBmyHA0oA5PatN/ur6MkzqU=";

    src = (
      pkgs.fetchFromGitHub {
        owner = "influxdata";
        repo = "inch";
        rev = "56a9750e91941d59a17ef2463d351513f378d9f4";
        sha256 = "sha256-UXg3+L4PMW8u5RLeDja0kYzxUnljhxVYe+p29XW4xoM=";
      }
    );
  };

  # how much to pause between batches when generating simulated metric data,
  # controls generation speed and load on InfluxDB
  writeDelay = if slowMode then "300ms" else "0";

  # cgroup/OOM limits for InfluxDB. Actual expected usage is smaller, this is
  # just to avoid OOM due to stress, see assertions.
  memoryMax = if slowMode then "500M" else "2G";

  # How much data to generate (and how much is stored in InfluxDB)
  localRetentionWeeks =
    if speedrun then
      1
    else
      # matches the default configuration
      12;
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

          virtualisation.memorySize = lib.mkForce 3000;

          playos.monitoring.enable = true;

          # collect faster in here
          playos.monitoring.collectionIntervalSeconds =
            if slowMode then
              10 # still 6x more frequent
            else
              1;
          playos.monitoring.localRetention = "${toString localRetentionWeeks}w";

          # enable frequent compaction to observe results quickly
          services.influxdb.extraConfig.data = {
            cache-snapshot-write-cold-duration = "1m";
            compact-full-write-cold-duration = "1m";
          };

          systemd.services.influxdb.serviceConfig = {
            MemoryMax = lib.mkForce memoryMax;
          };

          environment.systemPackages = [
            pkgs.influxdb
            inch_tool
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
    ''
      ${builtins.readFile ../helpers/nixos-test-script-helpers.py}
      import math
      import json

      ## CONSTANTS

      # How much space can the InfluxDB take on disk
      MAX_INFLUXDB_STORED_SIZE_MB = 300

      # How much memory we expect InfluxDB to use in a "steady" state
      # (compaction done, regular telegraf collection)
      MAX_INFLUXDB_PEAK_MEMORY_MB = 150

      MAX_TELEGRAF_PEAK_MEMORY_MB = 150

      SPEEDRUN = json.loads("${lib.boolToString speedrun}")
      if SPEEDRUN:
          print("===== RUNNING IN SPEEDRUN MODE =====")

      weeks = ${toString localRetentionWeeks}
      measurements = 10 # 1 measurement = 1 configured input plugin

      # Empirically we expect to have <100 unique tag values over ALL of the
      # measurements, so product of tag_cardinalities should be less than
      # 100/measurements
      tag_cardinalities = [2, 5]

      # 1 series = 1 unique tag combination within a measurement
      num_series = measurements * math.prod(tag_cardinalities)

      # each series will have this number of data fields
      fields = 5

      points_per_minute = 1
      points = weeks*7*24*60*points_per_minute

      ## HELPERS

      def run_query(query):
          res = machine.succeed(
              f"influx -database playos -format csv -execute '{query}'"
          ).strip().split('\n')
          # there should be at least a header
          assert len(res) > 1, f"Query '{query}' returned no data?"
          return res


      def check_cardinalities(t):
          measurements_list = run_query("SHOW MEASUREMENTS")
          total_measurements = len(measurements_list) - 1 # minus header

          series_list = run_query("SHOW SERIES")
          total_series = len(series_list) - 1

          fields_list = run_query("SHOW FIELD KEYS")
          total_fields = len(fields_list) - 1

          print(f"""
          Telegraf data collection produced:
          - {total_measurements} measurements
          - {total_series} unique series (measurements x tag_combos)
          - {total_fields} unique fields, for a...
          - {round(total_fields/total_measurements, 1)} avg. fields per measurement
          """)

          t.assertLess(total_series, num_series,
                           "Telegraf collected metrics exceed assumed max series count")
          t.assertLess(total_fields, measurements * fields,
                           "Telegraf collected metrics produced more fields than assumed")


      def get_memory_stats_mb(service):
          memory_current = machine.succeed(f"systemctl show {service} -p MemoryCurrent --value")
          memory_peak = machine.succeed(f"systemctl show {service} -p MemoryPeak --value")
          return {
              'memory_peak': int(memory_peak) / (1024*1024),
              'mem_current': int(memory_current) / (1024*1024)
          }

      def get_disk_usage_bytes():
          db_stored_size = machine.succeed("du --bytes -s /var/lib/influxdb | cut -f1")
          return int(db_stored_size)

      def print_memory_stats(stats):
          for k in stats:
              print(f"{k}: {round(stats[k])}MB")

      def get_and_print_memory_stats(service):
          stats = get_memory_stats_mb(service)
          print(f"{service} memory usage:")
          print_memory_stats(stats)
          return stats

      def check_stored_size(t):
          stored_bytes = get_disk_usage_bytes()
          stored_mb = round(stored_bytes / (1024*1024))
          print(f"Disk usage is: {stored_mb}MB")

          t.assertGreater(stored_bytes, 0,
              "Stored DB size is zero?")

          t.assertLess(stored_bytes, MAX_INFLUXDB_STORED_SIZE_MB * 1024 * 1024,
              f"Stored DB size exceeded {MAX_INFLUXDB_STORED_SIZE_MB}MB")


      ## TESTS

      machine.start()

      with TestPrecondition("influxdb and telegraf are running"):
          machine.wait_for_unit("influxdb.service", timeout=10)
          machine.wait_for_unit("telegraf.service", timeout=10)


      ## Stage 1: check if basic collection has no memory spikes

      sleep_duration = 1 if SPEEDRUN else 120
      print(f"Collecting Telegraf stats for {sleep_duration} seconds...")
      time.sleep(sleep_duration)

      with TestCase("Memory usage of Telegraf is reasonable") as t:
          telegraf_stats = get_and_print_memory_stats("telegraf.service")
          t.assertLess(telegraf_stats['memory_peak'], MAX_TELEGRAF_PEAK_MEMORY_MB)

      print("Stopping Telegraf to force data flush.")
      machine.systemctl("stop telegraf.service")

      with TestCase("Memory usage of InfluxDB is reasonable") as t:
          influxdb_stats = get_and_print_memory_stats("influxdb.service")
          t.assertLess(influxdb_stats['memory_peak'], MAX_INFLUXDB_PEAK_MEMORY_MB)

      ## Stage 2: run a stress test to backfill data for the whole retention

      with TestPrecondition("Cardinality of data collected by Telegraf matches stress test setup") as t:
          check_cardinalities(t)

      with TestCase(f"Generate {weeks} weeks of data (SLOW_MODE = ${lib.boolToString slowMode})"):
          res = machine.succeed(
          f"""inch \
                  -no-setup \
                  -max-errors 10 \
                  -db playos \
                  -precision s \
                  -randomize-fields \
                  -m {measurements} \
                  -f {fields} \
                  -t {",".join(map(str,tag_cardinalities))} \
                  -p {points} \
                  -delay ${writeDelay} \
                  -time -{weeks*7*24}h
          """)
          print(res)

      print("====== STATS IMMEDIATELLY AFTER ========")
      get_and_print_memory_stats("influxdb.service")
      # Note: memory limits enforced via MemoryMax, "realistic" memory only
      # checked at the end

      with TestCase("Disk usage after stress test is within limits") as t:
          check_stored_size(t)


      sleep_duration = 1 if SPEEDRUN else 120
      print(f"Sleeping for {sleep_duration} seconds to allow compaction...")
      time.sleep(sleep_duration)

      print("====== STATS AFTER compaction ========")
      get_and_print_memory_stats("influxdb.service")

      with TestCase("Disk usage after compaction is within limits") as t:
          check_stored_size(t)

      print("====== STATS AFTER restarting ========")
      machine.systemctl("restart influxdb.service")
      if not SPEEDRUN:
          time.sleep(10)
      stats = get_and_print_memory_stats("influxdb.service")

      with TestCase("InfluxDB memory usage after restart is within limits") as t:
          t.assertLess(stats['memory_peak'], MAX_INFLUXDB_PEAK_MEMORY_MB)

      with TestCase("Disk usage after restart is within limits") as t:
          check_stored_size(t)
    '';
}
