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
      # Use a dummy desktop manager that does no harm
      default = "xclock";
      session = [
        { name = "xclock";
          start = ''
            ${pkgs.xorg.xclock}/bin/xclock
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
      sessionCommands = "systemctl start --user play-kiosk";
    };
  };

  systemd.user.services."play-kiosk" = {
    description = "Dividay Play Kiosk";
    enable = true;
    # TODO Use Chromium or QtWebkit
    serviceConfig.ExecStart = "${pkgs.firefox}/bin/firefox https://play.dividat.com";
    serviceConfig.Restart = "always";
    # Prevent systemd from giving up on the kiosk if killed repeatedly
    serviceConfig.StartLimitIntervalSec = "0";
    serviceConfig.RestartSec = "1";
    wantedBy = [ "graphical.target" ];
  };

  # Driver service

  systemd.services."dividat-driver" = {
    description = "Dividat Driver";
    serviceConfig.ExecStart = "${pkgs.dividat-driver}/bin/dividat-driver";
    serviceConfig.User = "play";
    wantedBy = [ "multi-user.target" ];
  };

}
