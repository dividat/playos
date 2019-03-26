{config, pkgs, lib, ... }:
{
  # Localization configuration
  volatileRoot.persistentFolders."/var/lib/gui-localization" = {
    mode = "0755";
    user = "root";
    group = "root";
  };

  # Timezone

  # systemd stores timezone state as a symlink at /etc/localtime, can not just
  # mount this on persistent partition. Hence this service restores the timezone.
  systemd.services."set-timezone" = {
    description = "Set system timezone";
    serviceConfig = {
      User = "root";
      ExecStart = "/run/current-system/sw/bin/bash -c '/run/current-system/sw/bin/timedatectl set-timezone $(cat /var/lib/gui-localization/timezone)'";
    };
  };

  # Existence or modification of timezone file triggers service to set it.
  systemd.paths."set-timezone" = {
    pathConfig.PathExists = "/var/lib/gui-localization/timezone";
    pathConfig.PathChanged = "/var/lib/gui-localization/timezone";
    wantedBy = [ "multi-user.target" ];
  };

}
