{ config, pkgs, lib, ... }:
{

  # Cases where following is required include first run after installation or
  # after wiping the data partition.
  systemd.services."ensure-play-home-exists" = {
    description = "Ensure Play users home directory exists.";
    wantedBy = [ "multi-user.target" ];
    before = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      mkdir -p -m 0700 /data/home/play
      chown play:users /data/home/play
    '';
  };

  systemd.services."dividat-driver" = {
    description = "Dividat Driver";
    serviceConfig.ExecStart = "${pkgs.dividat-driver}/bin/dividat-driver";
    serviceConfig.User = "play";
    wantedBy = [ "multi-user.target" ];
  };

  services.xserver = {
    enable = true;
    displayManager = {
      # Automatically log in play user
      auto = {
        enable = true;
        user = "play";
      };

      # Warning: by going into an infinite loop here certain things are not
      # loaded properly (e.g. systemd user services). 
      # See <nixpkgs>/nixos/modules/services/x11/display-manager/default.nix.
      sessionCommands = ''
        while true
        do
          ${pkgs.chromium}/bin/chromium \
            --disable-infobars \
            --kiosk \
            --autoplay-policy=no-user-gesture-required \
            https://play.dividat.com

          sleep 3
        done
      '';
    };
  };

  users.users.play = {
    isNormalUser = true;
    home = "/data/home/play";
  };

}
