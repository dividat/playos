# Installs a service to disable power saving for all WiFi devices on boot.
#
# Unfortunately power saving has been implicated in random disconnects for some
# of our hardware configurations and customer APs. In simple tests observing
# consumed energy of an idle system using a Watt meter, there was no meaningful
# difference when power saving was disabled.
#
# We disable power saving for all detected WiFi devices without offering a
# documented way for the application layer to override, assuming any
# installations are stationary and mains powered. Powersaving behavior could be
# made configurable if use cases evolve going forward.
{ config, pkgs, ... }:

let
  disable-wifi-powersave-script = pkgs.writeShellScriptBin "disable-wifi-powersave" ''
    #!${pkgs.stdenv.shell}

    declare -a wireless_interfaces

    for iface in /sys/class/net/*; do
      if [ -d "$iface/wireless" ]; then
        wireless_interfaces+=("$(basename "$iface")")
      fi
    done

    iface_count=''${#wireless_interfaces[@]}
    if [ "$iface_count" -eq 0 ]; then
      echo "No wireless interfaces found. Nothing to do."
      exit 0
    else
      echo "Attempting to disable power_save on $iface_count wireless interfaces."
    fi

    for iface_name in "''${wireless_interfaces[@]}"; do
      set_output="$(${pkgs.iw}/bin/iw dev "$iface_name" set power_save off 2>&1)"
      if [ -n "$set_output" ]; then
        echo "Interface $iface_name: 'set power_save off' reported: $set_output"
      fi

      current_status="$(${pkgs.iw}/bin/iw dev "$iface_name" get power_save || echo unknown)"
      echo "$iface_name status: $current_status"
    done
  '';

in
{
  systemd.services.disable-all-wifi-powersave = {
    description = "Disable Wi-Fi power_save for all wireless interfaces";

    # Start after network is pre-configured but interfaces are not yet up
    after = [ "network-pre.target" ];
    before = [ "network.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;

      ExecStart = "${disable-wifi-powersave-script}/bin/disable-wifi-powersave";
    };

    wantedBy = [ "multi-user.target" ];
  };
}

