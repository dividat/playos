{ config, pkgs, lib, ... }:
{

  environment.systemPackages = with pkgs; [ rauc ];

  services.dbus.packages = with pkgs; [ rauc ];

  systemd.services.rauc = {
    description = "RAUC Update Service";
    serviceConfig.ExecStart = "${pkgs.rauc}/bin/rauc service";
    serviceConfig.User = "root";
    wantedBy = [ "multi-user.target" ];
  };

  environment.etc."rauc/system.conf" = {
    source = ./system.conf;
  };

  environment.etc."rauc/cert.pem" = {
    source = config.playos.updateCert;
  };
}
