{config, pkgs, lib, ... }:

let

  timezonePath = "/var/lib/gui-localization/timezone";

in {

  # Localization configuration
  playos.storage.persistentFolders."/var/lib/gui-localization" = {
    mode = "0755";
    user = "root";
    group = "root";
  };

  # Timezone

  # systemd stores timezone state as a symlink at /etc/localtime, can not just
  # mount this on persistent partition. Hence this service restores the timezone.
  systemd.services."set-timezone" = {
    description = "Set system timezone";
    wantedBy = [ "default.target" ]; # Run at startup
    serviceConfig = {
      User = "root";
      Group = "root";
      ExecStart = pkgs.writeShellScript "set-timezone" ''
        if [ -f ${timezonePath} ]; then
          timedatectl set-timezone $(cat ${timezonePath})
        fi
      '';
    };
  };

  # Modification of timezone file triggers service to set it.
  systemd.paths."set-timezone" = {
    pathConfig.PathChanged = timezonePath;
    wantedBy = [ "multi-user.target" ];
  };

}
