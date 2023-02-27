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

  # This service adjusts for a known weakness of the update mechanism that is due to the
  # use of the `/boot` partition for storing RAUC's statusfile. The `/boot` partition
  # was chosen to use FAT32 in order to use it as EFI system partition. FAT32 has no
  # journaling and so the atomicity guarantees RAUC tries to give for statusfile updates
  # are diminished. This service looks for leftovers from interrupted statusfile updates
  # and tries to recover.
  # Note that as previous installations will keep their boot partition unchanged even
  # after system updates, this or a similar recovery mechanism would be required even if
  # we change partition layout for new systems going forward.
  systemd.services.statusfile-recovery = {
    description = "status.ini recovery";
    serviceConfig.ExecStart = "${pkgs.bash}/bin/bash ${./recover-from-tmpfile} /boot/status.ini";
    serviceConfig.Type = "oneshot";
    serviceConfig.User = "root";
    serviceConfig.StandardOutput = "syslog";
    serviceConfig.SyslogIdentifier = "statusfile-recovery";
    serviceConfig.RemainAfterExit = true;
    wantedBy = [ "multi-user.target" ];
  };

  environment.etc."rauc/system.conf" = {
    source = ./system.conf;
  };

  environment.etc."rauc/cert.pem" = {
    source = config.playos.updateCert;
  };
}
