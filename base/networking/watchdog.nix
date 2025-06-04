{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.playos.networking.watchdog;
  watchdog =
    pkgs.writers.writePython3 "network-watchdog"
        { libraries = with pkgs.python3Packages; [ requests ];
          flakeIgnore = [ "E731" "E501" "E741" ];
        }
        (readFile ./watchdog.py);
in
{
  options = {
    playos.networking.watchdog = {
      enable = mkEnableOption "Run network watchdog";

      checkUrl = mkOption {
        example = "https://dividat.com";
        type = types.str;
      };

      altCheckUrl = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "https://api.dividat.com";
        description = "TODO";
      };

      maxNumFailures = mkOption {
        default = 3;
        type = types.ints.positive;
        description = "TODO";
      };

      checkInterval = mkOption {
        type = types.ints.positive;
        description = "Interval for checking `checkUrl` in seconds";
        default = 60*3;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services."playos-network-watchdog" = {
      description = "PlayOS network watchdog";

      after = [ "network.target" ];
      requires = [ "connman.service" ]; # TODO: wpa_supplicant?
      wantedBy = [ "multi-user.target" ];


      serviceConfig = {
        StandardOutput = "journal";
        StandardError = "inherit";
        Environment = "PYTHONUNBUFFERED=1";
        ExecStart = ''${watchdog} \
                --check-url '${cfg.checkUrl}' \
                --max-num-failures ${toString cfg.maxNumFailures} \
                --check-interval ${toString cfg.checkInterval}''
                + optionalString (cfg.altCheckUrl != null) " --alt-check-url '${cfg.altCheckUrl}'";

        User = "root";
        RestartSec = "10s"; # TODO: ??
        Restart = "always"; # TODO: ?? - either the watchdog can exit and expected to be restarted or run forever
      };
    };


  };
}


