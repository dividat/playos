{ config, pkgs, lib, ... }:
{

  # Configure kiosk user with home folder on /data

  users.users.play = {
    isNormalUser = true;
    home = "/home/play";
  };

  fileSystems."/home/play" = {
    device = "/data/home/play";
    options = [ "bind" ];
  };

  boot.postBootCommands = lib.mkAfter ''
    mkdir -p -m 0700 /data/home/play
    chown play:users /data/home/play
  '';

  # Kiosk session

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


  # Driver service

  systemd.services."dividat-driver" = {
    description = "Dividat Driver";
    serviceConfig.ExecStart = "${pkgs.dividat-driver}/bin/dividat-driver";
    serviceConfig.User = "play";
    wantedBy = [ "multi-user.target" ];
  };

}
