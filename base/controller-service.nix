{ config, pkgs, lib, playos-controller }:
let
  cfg = config.playos.controller;
  hasAnnotatedServices = cfg.annotateDiscoveredServices != [];
in
with lib;
{
  options = {
    playos.controller = {
      annotateDiscoveredServices = mkOption {
        default = [];
        example = [ "_ftp._tcp" ];
        description = "DNS-SD service types to browse for and annotate networks with in controller UI"; 
        type = types.listOf types.str;
      };
    };
  };

  config = {
    assertions = [
      {
        assertion = !hasAnnotatedServices || config.services.avahi.enable;
        message = "playos.controller.annotateDiscoveredServices requires avahi to be enabled.";
      }
    ];

    services.avahi.enable = mkIf hasAnnotatedServices true;

    # Use the persistent partition for storing controller state only to avoid
    # storing the RAUC bundles in memory (tmpfs)
    playos.storage.persistentFolders."/var/lib/playos-controller" = {
      mode = "0755";
      user = "root";
      group = "root";
    };

    systemd.services =
    let
      systemdServices = {
        playos-controller = {
          description = "PlayOS Controller";
          serviceConfig = {
            ExecStart = "${playos-controller}/bin/playos-controller";
            User = "root";
            RestartSec = "10s";
            Restart = "always";
            ExecStartPre = "-${pkgs.writeShellScript "clear-state" ''
                rm -rf /var/lib/playos-controller/*
                rm -rf /var/lib/playos-controller/.*
            ''}";
            StateDirectory = "playos-controller";
          };
          wantedBy = [ "multi-user.target" ];
          requires = [ "connman.service" ];
          after = [ "rauc.service" "connman.service" ];
          # DNS-SD annotations
          path = mkIf hasAnnotatedServices [ pkgs.avahi ];
          environment = {
            PLAYOS_ANNOTATE_DISCOVERED_SERVICES =
              mkIf hasAnnotatedServices (concatStringsSep ";" cfg.annotateDiscoveredServices);
          };
        };
      };
    in
    # Create a proactive service browser for each annotated service type
    # This ensures that we don't rely on the application's actions for letting
    # avahi build a service table.
    lib.foldl' (acc: serviceType:
      acc // {
        "avahi-browse-${lib.escapeShellArg serviceType}" = {
          description = "Proactively browse DNS-SD for ${serviceType}";
          after = [ "avahi-daemon.service" ];
          requires = [ "avahi-daemon.service" ];

          serviceConfig = {
            ExecStart = "${pkgs.avahi}/bin/avahi-browse ${serviceType}";
            Restart = "always";
            RestartSec = "5s";
          };

          wantedBy = [ "multi-user.target" ];
        };
      }
    ) systemdServices cfg.annotateDiscoveredServices;
  };

}
