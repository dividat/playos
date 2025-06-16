{ config, pkgs, lib, ... }:
with lib;
with pkgs;
let
  cfg = config.playos.networking.watchdog;
  watchdog = python3Packages.buildPythonApplication rec {
      pname = "playos_network_watchdog";
      version = "0.1.0";

      src = ./.;

      nativeBuildInputs = [
          wrapGAppsHook
      ];

      flakeIgnore = [ "E731" "E501" "E741" ];

      propagatedBuildInputs = with python3Packages; [
          dbus-python
          pygobject3
          requests
      ];
  };
in
{
  options = {
    playos.networking.watchdog = {
      enable = mkEnableOption "Run network watchdog";

      checkURLs = mkOption {
        example = [ "https://play.dividat.com" "https://api.dividat.com" ];
        type = types.nonEmptyListOf types.str;
        description = "List of URLs to determine if internet is reachable. If at least one URL is reachable, then we believe internet is reachable. URLs are tried sequentially";
      };

      maxNumFailures = mkOption {
        default = 3;
        type = types.ints.positive;
        description = "How many times to check before determining that internet connectivity is “lost”. Total wait time is `maxNumFailures * checkInterval`";
      };

      checkInterval = mkOption {
        type = types.ints.positive;
        description = "Interval for checking `checkUrl` in seconds";
        default = 60*3;
      };

      settingChangeDelay = mkOption {
        default = 60*5;
        type = types.ints.positive;
        description = "How many seconds to pause the watchdog for after any connman (service) setting changes (e.g. user has changed the wifi passphrase).";
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
        ExecStart =
            let
                checkURLflags = lib.strings.concatMapStrings (url: "--check-url '${url}'") cfg.checkURLs;
            in
            ''${watchdog}/bin/playos-network-watchdog \
                 ${checkURLflags} \
                --max-num-failures ${toString cfg.maxNumFailures} \
                --check-interval ${toString cfg.checkInterval} \
                --setting-change-delay ${toString cfg.settingChangeDelay}'';
        User = "root";
        RestartSec = "10s"; # TODO: ??
        Restart = "always"; # TODO: ?? - either the watchdog can exit and expected to be restarted or run forever
      };
    };


  };
}


