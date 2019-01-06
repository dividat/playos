{ config, pkgs, lib, ... }:
{

  environment.systemPackages = with pkgs; [ rauc ];

  services.dbus.packages = with pkgs; [ rauc ];

  systemd.services.rauc-mark-good = {
    description = "RAUC mark system as good";
    serviceConfig.ExecStart = "${pkgs.rauc}/bin/rauc status mark-good";
    serviceConfig.User = "root";
    wantedBy = [ "multi-user.target" ];
    requires = [ "rauc" ];
  };

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
    source = config.playos.keyring;
  };
}
