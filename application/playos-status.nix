{ config, lib, pkgs, ... }:
let
  ttyNumber = 8;
  tty = "tty${toString ttyNumber}";
  ttyPath = "/dev/${tty}";
  driverUrl = "http://127.0.0.1:8382";
  dataPath = config.playos.storage.persistentDataPartition.mountPath;

  script =
    pkgs.writeShellScriptBin "print-status" ''
      while :; do
        screen=$(xrandr --current | grep '*' | awk '{print $1}')
        networkCount=$(connmanctl services | grep wifi | wc -l)
        ethernetMacs=$(cat /sys/class/net/e*/address 2>/dev/null | grep -v '^$' | awk '{print "Ethernet " $0}' | tr '\n' '  ')
        wlanMacs=$(cat /sys/class/net/wl*/address 2>/dev/null | grep -v '^$' | awk '{print "WLAN " $0}' | tr '\n' '  ')
        rfid=$(opensc-tool --list-readers | pr -T -o 2)
        dataDiskFree=$(df -h ${dataPath} | pr -T -o 2)
        controller=$(systemctl is-active playos-controller)
        time=$(date +'%T %Z')
        printf "\033c"
        printf "%s\n\n" \
          "Screen dimensions: $screen" \
          "Wi-Fi networks found: $networkCount" \
          "RFID readers connected:" \
          "$rfid" \
          "Persistent storage:" \
          "$dataDiskFree" \
          "Controller: $controller" \
          "Network interfaces:" \
          "  $ethernetMacs  $wlanMacs" \
          > ${ttyPath}
        qrencode -m 2 -t utf8 <<< "$ethernetMacs  $wlanMacs" \
          | pr -T -o 2 \
          > ${ttyPath}
        printf "\n%s" "Updated at: $time" > ${ttyPath}
        sleep 5
      done
    '';
in
{
  config = {
    systemd.services.playos-status = {
      environment = {
        XAUTHORITY = "${config.users.users.play.home}/.Xauthority";
        DISPLAY = ":0";
      };
      path = with pkgs; [
        connman
        gnugrep
        gawk
        xorg.xrandr
        opensc
        coreutils
        qrencode
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
