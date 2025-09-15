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

    nativeCheckInputs = with python3Packages; [
        types-requests
        ruff
        mypy
    ];

    checkPhase = ''
        runHook preCheck

        ruff check

        mypy \
            --no-color-output \
            --pretty \
            --exclude 'build/.*' \
            --exclude setup.py \
            .

        runHook postCheck
     '';

      propagatedBuildInputs = with python3Packages; [
          dbus-python
          pygobject3
          requests
          playos-proxy-utils
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
        description = "List of URLs to determine if internet is reachable. If at least one URL is reachable, then we believe internet is reachable. URLs are tried sequentially.";
      };

      maxNumFailures = mkOption {
        default = 3;
        type = types.ints.positive;
        description = "How many times to check before determining that internet connectivity is “lost”. Total wait time is `(maxNumFailures - 1) * checkInterval` plus a worst-case factor `(maxNumFailures - 1) *len(checkURLs) * checkUrlTimeout`";
      };

      checkInterval = mkOption {
        type = types.numbers.positive;
        description = "Interval for checking `checkUrl` in seconds";
        default = 60*3;
      };

      settingChangeDelay = mkOption {
        default = 60*5;
        type = types.numbers.positive;
        description = "How many seconds to pause the watchdog for after any connman (service) setting changes (e.g. user has changed the wifi passphrase).";
      };

      checkUrlTimeout = mkOption {
        default = 5;
        type = types.numbers.positive;
        description = "Timeout in seconds for the individual HTTP request.";
      };

      debug = mkOption {
        default = false;
        type = types.bool;
        description = "Run watchdog in debug mode (verbose logging)";
      };

      configDir = mkOption {
        description = "Hard-coded config path used for disabling the watchdog via controller";
        readOnly = true;
        default = "/home/play/.config/playos-network-watchdog";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services."playos-network-watchdog" = {
      description = "PlayOS network watchdog";

      after = [ "network.target" "connman.service" ];
      wantedBy = [ "multi-user.target" ];

      # allow to persistently disable using controller UI
      unitConfig.ConditionPathExists = "!${cfg.configDir}/disabled";

      serviceConfig = {
        StandardOutput = "journal";
        StandardError = "inherit";
        Environment = "PYTHONUNBUFFERED=1";
        ExecStart =
            let
                checkURLflags = lib.strings.concatMapStrings (url: " --check-url '${url}'") cfg.checkURLs;
            in
            ''${watchdog}/bin/playos-network-watchdog \
                 ${checkURLflags} \
                --max-num-failures ${toString cfg.maxNumFailures} \
                --check-interval ${toString cfg.checkInterval} \
                --check-url-timeout ${toString cfg.checkUrlTimeout} \
                --setting-change-delay ${toString cfg.settingChangeDelay}''
                + (lib.optionalString cfg.debug " --debug");
        User = "root";
        RestartSec = "10s";
        Restart = "always";
      };
    };

  };
}
