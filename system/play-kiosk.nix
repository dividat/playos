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
      default = "chromium-kiosk";
      session = [
        { name = "chromium-kiosk";
          start = ''
            # Disable screen-saver control (screen blanking)
            xset s off

            # chromium sometimes fails to load properly if immediately started
            sleep 1
            # --window-size is a hack, see here: https://unix.stackexchange.com/questions/273989/how-can-i-make-chromium-start-full-screen-under-x
            ${pkgs.chromium}/bin/chromium \
              --no-sandbox \
              --no-first-run \
              --noerrdialogs \
              --start-fullscreen \
              --start-maximized \
              --window-size=9000,9000 \
              --disable-notifications \
              --disable-infobars \
              --disable-save-password-bubble \
              --autoplay-policy=no-user-gesture-required \
              --kiosk https://play.dividat.com/
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

  # Enable avahi for Senso discovery
  services.avahi.enable = true;

  # Enable pcscd for smart card identification
  services.pcscd.enable = true;

}
