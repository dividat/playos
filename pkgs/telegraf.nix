# Build a minimal version of telegraf with only the plugins we actually use.
#
# Note: this relies on Telegraf's config validation in base/monitoring to detect
# missing plugins.
#
# See https://github.com/influxdata/telegraf/blob/master/docs/CUSTOMIZATION.md
# for details.
super:
let
  supportedPlugins = [
    "inputs.cpu"
    "inputs.disk"
    "inputs.mem"
    "inputs.net"
    "inputs.procstat"
    "inputs.system"
    "inputs.sensors"
    "inputs.systemd_units"
    "inputs.wireless"

    "outputs.influxdb"

    "processors.strings"
    ];
in
super.telegraf.overrideAttrs (old: {
  tags = (old.tags or []) ++ ["custom"] ++ supportedPlugins;

  doCheck = false; # tests require non-custom build
})
