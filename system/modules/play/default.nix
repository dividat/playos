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
      # Always automatically log in play user
      lightdm = {
        enable = true;
        greeter.enable = false;
        autoLogin = {
          enable = true;
          user = "play";
          timeout = 0;
        };
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
