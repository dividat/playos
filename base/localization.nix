{config, pkgs, lib, ... }:

let

  timezonePath = "/var/lib/gui-localization/timezone";

  supportedLanguages = [
      { locale = "cs_CZ.UTF-8"; name = "Czech"; }
      { locale = "nl_NL.UTF-8"; name = "Dutch"; }
      { locale = "en_GB.UTF-8"; name = "English (UK)"; }
      { locale = "en_US.UTF-8"; name = "English (US)"; }
      { locale = "fi_FI.UTF-8"; name = "Finnish"; }
      { locale = "fr_FR.UTF-8"; name = "French"; }
      { locale = "de_DE.UTF-8"; name = "German"; }
      { locale = "it_IT.UTF-8"; name = "Italian"; }
      { locale = "pl_PL.UTF-8"; name = "Polish"; }
      { locale = "es_ES.UTF-8"; name = "Spanish"; }
   ];

   supportedKeymaps = [
      { keymap = "cz"; name = "Czech"; }
      { keymap = "nl"; name = "Dutch"; }
      { keymap = "gb"; name = "English (UK)"; }
      { keymap = "us"; name = "English (US)"; }
      { keymap = "fi"; name = "Finnish"; }
      { keymap = "fr"; name = "French"; }
      { keymap = "de"; name = "German"; }
      { keymap = "ch"; name = "German (Switzerland)"; }
      { keymap = "it"; name = "Italian"; }
      { keymap = "pl"; name = "Polish"; }
      { keymap = "es"; name = "Spanish"; }
    ];

in {
  environment.etc."playos/keymaps.json".text = builtins.toJSON supportedKeymaps;
  environment.etc."playos/languages.json".text = builtins.toJSON supportedLanguages;

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
