{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.playos.monitoring;
  localDatabase = cfg.localDbName;
  dbRetention = cfg.localRetention;
in
{
  imports = [
    ./volatile-root.nix
  ];

  options = {
    playos.monitoring = with lib; {
      enable = mkEnableOption "Enable system monitoring tools";

      localDbName = mkOption {
        default = "playos";
        type = types.str;
      };

      localRetention = mkOption {
        default = "12w";
        example = "30d";
        description = ''
          How long to keep data in the local DB. Specified as duration unit string.
          See:
              https://docs.influxdata.com/influxdb/v1/query_language/manage-database/#retention-policy-management
              https://docs.influxdata.com/influxdb/v1/query_language/spec/#durations
        '';
        type = types.str;
      };

      localDbShard = mkOption {
        default = "1w";
        example = "3d;";
        description = "InfluxDB shard duration (size). Must be smaller than localRetention duration. See localRetention for references";
        type = types.str;
      };

      collectionIntervalSeconds = mkOption {
        default = 60;
        description = "Interval at which to collect metrics (in seconds)";
        type = types.ints.between 1 (60 * 60);
      };

      extraServices = mkOption {
        default = [ ];
        description = "List of extra systemd service names (globs) to monitor";
        type = types.listOf types.str;
      };
    };
  };

  config =
    let
      defaultResourceScalingWeight = 100; # cgroup default

      commonServiceConfig = {
        # restart with delay and backoff
        Restart = lib.mkForce "always";
        RestartMaxDelaySec = "10min";
        RestartSteps = 10;

        # stop restarting after 20 attemps
        StartLimitIntervalSec = "infinity";
        StartLimitBurst = 20;

        # limit resource usage
        CPUWeight = defaultResourceScalingWeight / 10;
        IOWeight = defaultResourceScalingWeight / 10;
      };

      # A slightly silly, but helpful way to validate Telegraf's config.
      # Due to the nix->TOML transformation and Telegraf's weird spec
      # it is very easy to accidentally produce a broken config.
      telegrafConfigIsValid =
        let
          telegrafCfg = config.services.telegraf;
          settingsFormat = pkgs.formats.toml { };
          configFile = settingsFormat.generate "config.toml"
            (lib.recursiveUpdate telegrafCfg.extraConfig {agent.debug = true; });
          stubSensorsBin = pkgs.writeShellScriptBin "sensors" ''true'';
        in
          pkgs.runCommand
            "validate-config"
            { buildInputs = [pkgs.telegraf] ++ config.systemd.services.telegraf.path;  }
            ''
            set -euo pipefail

            echo "=== Validating telegraf's config..."

            # provide a stub `sensors` bin, because input.sensors fails if there
            # are no sensors available while the real `sensors` from pkgs.lm-sensors
            export PATH=${stubSensorsBin}/bin:$PATH

            if telegraf --config ${configFile} --test &> output.txt; then
              echo "=== Config seems good!"
              touch $out
            else
              echo "=== Config validation FAILED, config was:"
              cat ${configFile}

              echo "=== Telegraf output:"
              cat output.txt

              echo "Hint: PlayOS uses a custom build of telegraf, so if you get"
              echo "an error like 'undefined but requested input', this can mean"
              echo "two things:"
              echo "  1. Typo / wrong name of plugin"
              echo "  2. Plugin is not included in custom build, check pkgs/telegraf.nix"

              exit 1
            fi
            '';

    in
    lib.mkIf cfg.enable {
      system.checks = [ telegrafConfigIsValid ];

      ### InfluxDB --- local metric storage

      services.influxdb.enable = true;

      playos.storage.persistentFolders."${config.services.influxdb.dataDir}" = {
        mode = "0700";
        user = config.services.influxdb.user;
        group = config.users.users."${config.services.influxdb.user}".group;
      };

      # for maintenance ops
      environment.systemPackages = [ pkgs.influxdb ];

      systemd.services.influxdb.serviceConfig = commonServiceConfig // {
        # for the socket file
        RuntimeDirectory = "influxdb";
        # for db / data
        StateDirectory = "influxdb";

        MemoryMax = "200M";

        # limit to two cores
        Environment = "GOMAXPROCS=2";
      };

      services.influxdb.dataDir = "/var/lib/influxdb"; # use the standard dir

      services.influxdb.extraConfig = {
        reporting-disabled = true;

        http = {
          enabled = true;

          bind-address = "localhost:8086";
          unix-socket-enabled = true;
          bind-socket = "/var/run/influxdb/influxdb.sock";

          auth-enabled = false;
          log-enabled = false;
          write-tracing = false;
          pprof-enabled = false;
        };

        meta = {
          retention-autocreate = false;
        };

        data = {
          query-log-enabled = false;

          # avoid accidental cardinality explosions
          max-series-per-database = 4000;
          max-values-per-tag = 100;

          # reject writes if cache grows big
          cache-max-memory-size = "200m";

          # do one thing at a time
          max-concurrent-compactions = 1;
        };

        logging.level = "warn";
        logging.suppress-logo = true;

        monitor.store-enabled = false;
        subscriber.enabled = false;
        continuous_queries.enabled = false;
        admin.enabled = false;
        hinted-handoff.enabled = false;
      };

      ### Telegraf --- metric collection

      services.telegraf.enable = true;

      systemd.tmpfiles.rules = [
        "f '/var/cache/telegraf/env-file' 0755 telegraf telegraf - -"
      ];

      # expose machine-id via an env file and setup the DB
      systemd.services.telegraf-setup = {

        serviceConfig.ExecStart = lib.getExe (
          pkgs.writeShellApplication {
            name = "telegraf-setup";
            runtimeInputs = with pkgs; [
              influxdb
              gnugrep
            ];
            text = ''
              echo "MACHINE_ID=$(cat /etc/machine-id)" > /var/cache/telegraf/env-file

              result_file=$(mktemp)
              trap 'rm -f $result_file' EXIT

              influx -format csv -execute "SHOW DATABASES" > "$result_file"

              if grep -q ${localDatabase} "$result_file"; then
                  echo "Database '${localDatabase}' exists, nothing to do"
              else
                  echo "Creating ${localDatabase}"
                  influx -execute 'CREATE DATABASE ${localDatabase}; CREATE RETENTION POLICY "${dbRetention}" ON ${localDatabase} DURATION ${dbRetention} REPLICATION 1 SHARD DURATION ${cfg.localDbShard} DEFAULT; '
              fi
            '';
          }
        );

        serviceConfig.Type = "oneshot";
        serviceConfig.User = "telegraf";

        requires = [ "influxdb.service" ];
        after = [ "influxdb.service" ];

        before = [ "telegraf.service" ];
        requiredBy = [ "telegraf.service" ];
      };

      systemd.services.telegraf.serviceConfig = commonServiceConfig // {
        EnvironmentFile = "/var/cache/telegraf/env-file";

        MemoryMax = "60M";
      };

      systemd.services.telegraf.path = [
        pkgs.dbus # for inputs.systemd_units
      ];

      # NOTE: if you add new inputs/ouputs or other configuration options that
      # require extra telegraf dependencies, you need to also modify pkgs/telegraf.nix
      services.telegraf.extraConfig = with builtins; rec {
        global_tags.playos_version = lib.mkIf (config.playos ? "version") config.playos.version;

        agent = {
          quiet = true;
          hostname = "playos-\${MACHINE_ID}";

          always_include_global_tags = true;

          interval = "${toString cfg.collectionIntervalSeconds}s";
          precision = "${toString (ceil (cfg.collectionIntervalSeconds / 2.0))}s";

          # don't launch all collectors at once
          collection_jitter = "${toString (ceil (cfg.collectionIntervalSeconds / 5.0))}s";

          # avoid buffering many things to reduce mem usage
          metric_batch_size = 50;
          metric_buffer_limit = 100;
        };

        outputs.influxdb = {
          urls = [ "unix:///var/run/influxdb/influxdb.sock" ];
          database = "${localDatabase}";
          content_encoding = "identity"; # don't compress
          skip_database_creation = true; # we set up the DB manually
        };

        ## INPUTS: collected metrics

        inputs.mem = {
          fieldinclude = [
            "cached"
            "free"
            "mapped"
            "used"
            "slab"
            "shared"
            "available"
          ];
        };

        inputs.cpu = {
          # gather stats summed over all CPUs
          totalcpu = true;
          # gather per-CPU stats
          percpu = true;

          # We exclude 'active' and rely on plotting setup to sum up the parts,
          # since telegraf has an awkward definition of 'active' that includes
          # `iowait`. This differs from the interpretation in standard tools
          # like like top/htop and does not reflect CPU business.
          report_active = false;

          fieldinclude = [
            "usage_user"
            "usage_system"
            "usage_idle"
            "usage_nice"
            "usage_iowait"
            "usage_irq"
            "usage_softirq"
          ];
        };

        inputs.system = {
          fieldinclude = [
            "load*"
          ];
        };

        inputs.disk = {
          # drop all the metadata tags except path
          taginclude = [ "path" ];
          interval = "5m"; # collect every 5 minutes, we don't expect big fluctuations here
          mount_points = [
            "/" # tmpfs overlay
            config.playos.storage.persistentDataPartition.mountPath # /mnt/data
          ];

          fieldinclude = [
            "free"
            "used"
            "inodes_used"
          ];
        };

        inputs.wireless = {
          # keeping many fields for now, to help debug wireless issues
          fieldinclude = [
            "status"
            "level"
            "noise"
            "retry" # cumulative retry counts
            "misc" # packets dropped for un-specified reason
            "missed_beacon" # missed beacon packets
          ];
        };

        inputs.net = {
          interfaces = [
            "wl*"
            "eth*"
            "en*"
          ];
          fieldinclude = [
            "bytes_sent"
            "bytes_recv"
            "err_in"
            "err_out"
            "drop_in"
            "drop_out"
          ];
          ignore_protocol_stats = true;
        };

        # memory usage by dfferent systemd units
        # (the plugin, as of v1.36.4, does not return IO or CPU stats)
        inputs.systemd_units =
          let
            generalStuff = {
              # drop all the metadata tags except name
              taginclude = [ "name" ];
              fieldinclude = [ "mem_current" ];

              scope = "system";
              details = true;
            };
          in
          lib.lists.map (x: generalStuff // x) [
            # memory usage by system processes and per user
            {
              unittype = "slice";
              pattern = lib.strings.concatStringsSep " " [
                "system.slice"
                "user-*.slice"
              ];
            }
            # memory usage by core services
            {
              unittype = "service";
              pattern = lib.strings.concatStringsSep " " (
                [
                  "telegraf.service"
                  "influxdb.service"
                  "connman.service"
                  "playos-*"
                ]
                ++ cfg.extraServices
              );
            }
          ];

          inputs.kernel = {
            # collect CPU, IO and memory pressure information
            collect = [ "psi" ];
            fieldinclude = [
              # 'kernel' metric fields
              "boot_time"
              "entropy_avail"
              "processes_forked"

              # 'pressure' metric fields
              "avg10"
              "avg60"
              "avg300"
            ];

          };

          inputs.diskio = {
            skip_serial_number = true;
            fieldinclude = [
              "reads"
              "writes"
              "read_time"
              "write_time"
              "io_await"
              "io_util"
            ];
          };
      };

    };
}
