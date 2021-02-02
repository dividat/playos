{ config, lib, pkgs, ... }:
let
  ttyNumber = 8;
  tty = "tty${toString ttyNumber}";
  ttyPath = "/dev/${tty}";
  driverUrl = "http://127.0.0.1:8382";

  script =
    pkgs.writeShellScriptBin "print-status" ''
      while :; do
        printf "\033c"
        screen=$(xrandr --current | grep '*' | awk '{print $1}')
        network=$(connmanctl technologies | grep 'Type\|Connected')
        rfid=$(curl -s "${driverUrl}/rfid/readers" | jq -r ".readers" | jq length)
        controller=$(systemctl is-active playos-controller)
        printf "%s\n" \
          "Screen dimensions: $screen" \
          "Network connection:" \
          "$network" \
          "RFID: $rfid" \
          "Controller: $controller" \
          > ${ttyPath}
        sleep 5
      done
    '';
in
{
  config = {
    console.extraTTYs = [ tty ];
    systemd.services.playos-status = {
      environment = {
        XAUTHORITY = "${config.users.users.play.home}/.Xauthority";
        DISPLAY = ":0";
      };
      path = with pkgs; [
        connman
        curl
        gnugrep
        gawk
        jq
        xorg.xrandr
      ];
      description = "PlayOS status";
      wantedBy = [ "multi-user.target" ];
      after = [ "playos-controller.service" ];
      serviceConfig = {
        ExecStart = "${script}/bin/print-status";
        User = "root";
        StandardOutput = "tty";
        TTYPath = ttyPath;
      };
    };
  };
}
