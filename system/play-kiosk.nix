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

    desktopManager = {
      xterm.enable = false;
      # "Boot to Gecko"
      default = "firefox";
      session = [
        { name = "firefox";
          start = ''
            ${pkgs.firefox}/bin/firefox https://play.dividat.com/
            waitPID=$!
          '';
        }
      ];
    };

    displayManager = {
      # Automatically log in play user
      auto = {
        enable = true;
        user = "play";
      };
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
