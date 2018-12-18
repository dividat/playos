{ config, pkgs, lib, ... }:
{

  # Configure kiosk user with home folder on /data

  users.users.play = {
    isNormalUser = true;
    home = "/home/play";
  };

  # Note that setting up "/home" as persistent fails due to https://github.com/NixOS/nixpkgs/issues/6481
  volatileRoot.persistentFolders."/home/play" = {
    mode = "0700";
    user = "play";
    group = "users";
  };

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
