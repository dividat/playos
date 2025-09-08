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
        assertion = !(hasAnnotatedServices && config.services.avahi.enable == false);
        message   = "playos.controller.annotateDiscoveredServices requires avahi to be enabled.";
      }
    ];

    services.avahi.enable = mkIf hasAnnotatedServices true;

    systemd.services.playos-controller = {
      description = "PlayOS Controller";
      serviceConfig = {
        ExecStart = "${playos-controller}/bin/playos-controller";
        User = "root";
        RestartSec = "10s";
        Restart = "always";
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

}
