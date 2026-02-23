# Metric plotting in Grafana

This directory contains a nix flake that allows to spin up a local Grafana
instance with preconfigured dashboards for PlayOS metric analysis (stored in
InfluxDB, see [base/monitoring.nix](../../base/monitoring.nix)).

## Quick start

Forward the InfluxDB port from a remote PlayOS machine:

    ssh -N -L 8086:localhost:18086 root@playos-machine-somewhere

Enter the dev shell:

    nix develop

Start Grafana, pointing it to InfluxDB:

    ./run-grafana --influxdb-url http://localhost:18086/

Click the provided auto-login link or open http://localhost:9090/ and login with
admin / admin.

See "Dashboards" in the Grafana menu for a list of available dashboards.

## Creating and editing Dashboards

The [dashboards](dashboards/) folder contains definitions of several dashboards
that are provided by default. They cover most of the collected metrics and are a
good starting point.

You can create or modify dashboards in two ways:

1. Directly editing or adding the JSON files in `dashboards/*.json`
2. Making changes in the Grafana UI and re-exporting the dashboards.

Option 1 is cumbersome in most situations and useful only for programmatic batch edits.

Option 2 is done like this:

- Make changes to the dashboards via the Grafana UI
- Click "Save dashboard"
- Either run `./export-dashboards` or simply stop `./run-grafana` with Ctrl+C and answer "y"
  when asked to re-export dashboards.
- `git diff dashboards/` and commit the changes to git as needed.

Add new dashboards you create will also be re-exported.

Avoid saving temporary changes such as default time range modifications, graph
sizes or custom filters.

Note: to ensure Grafana loads and displays the saved dashboards, it is recommended to
do clear persistent data and restart Grafana:

    git clean -fdx ./rundir
    ./run-grafana --influxdb-url ...

## Serving metric data locally

Currently there are two ways to do this:

### Via QEMU (for testing only)

You can build a modified version of PlayOS VM and forward the InfluxDB port to
the host:
- set `networking.firewall.enabled = false`
- set `services.influxdb.extraConfig.http.bind-address = "0.0.0.0:8086"`
- build `./build vm`
- run with `./result/bin/run-in-vm -q -enable-kvm -nic user,hostfwd=tcp::8086-:8086`

However, note that this does not include all metrics: sensor, wireless and
diskio stats are note available on the VM.

### Via InfluxDB backup (for testing and/or analysis)

Obtain an InfluxDB backup from a real system, e.g.:

    ssh <machine>
    ...
    influxdb backup -portable /tmp/influxdb-backup
    ...
    scp -r <machine>:/tmp/influxdb-backup /some/folder

Then start a local InfluxDB instance and recover the data into it:

    nix-shell -p influxdb
    influxd run # start influxdb
    influxd restore -portable <path-to-backup-folder>
