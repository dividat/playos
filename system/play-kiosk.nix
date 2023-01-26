{ config, pkgs, ... }:

{

  # Kiosk runs as a non-privileged user
  users.users.play = {
    isNormalUser = true;
    home = "/home/play";
    extraGroups = [
      "dialout" # Access to serial ports for the Senso flex
    ];
  };

  # Note that setting up "/home" as persistent fails due to https://github.com/NixOS/nixpkgs/issues/6481
  volatileRoot.persistentFolders."/home/play" = {
    mode = "0700";
    user = "play";
    group = "users";
  };

  # System-wide packages
  environment.systemPackages = with pkgs; [
    breeze-contrast-cursor-theme
  ];

  # Kiosk session
  services.xserver = let sessionName = "kiosk-browser"; in {
    enable = true;

    desktopManager = {
      xterm.enable = false;
      session = [
        { name = sessionName;
          start = ''
            # Disable screen-saver control (screen blanking)
            xset s off
            xset s noblank
            xset -dpms

            # Localization for xsession
            if [ -f /var/lib/gui-localization/lang ]; then
              export LANG=$(cat /var/lib/gui-localization/lang)
            fi
            if [ -f /var/lib/gui-localization/keymap ]; then
              setxkbmap $(cat /var/lib/gui-localization/keymap) || true
            fi

            # force resolution
            scaling_pref=/var/lib/gui-localization/screen-scaling
            if [ -f "$scaling_pref" ] && [ $(cat "$scaling_pref") = "full-hd" ]; then
               xrandr --size 1920x1080
            fi

            # Enable Qt WebEngine Developer Tools (https://doc.qt.io/qt-5/qtwebengine-debugging.html)
            export QTWEBENGINE_REMOTE_DEBUGGING="127.0.0.1:3355"

            ${pkgs.playos-kiosk-browser}/bin/kiosk-browser \
              ${config.playos.kioskUrl} \
              http://localhost:3333/

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
        autoLogin.timeout = 0;
      };

      autoLogin = {
        enable = true;
        user = "play";
      };

      defaultSession = sessionName;

      sessionCommands = ''
        ${pkgs.xorg.xrdb}/bin/xrdb -merge <<EOF
          Xcursor.theme: ${pkgs.breeze-contrast-cursor-theme.themeName}
        EOF
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

  # Audio
  sound.enable = true;
  hardware.pulseaudio = {
    enable = true;
  };

  # Enable avahi for Senso discovery
  services.avahi.enable = true;

  # Enable pcscd for smart card identification
  services.pcscd.enable = true;
  # Blacklist NFC modules conflicting with CCID (https://ludovicrousseau.blogspot.com/2013/11/linux-nfc-driver-conflicts-with-ccid.html)
  boot.blacklistedKernelModules = [ "pn533_usb" "pn533" "nfc" ];
  # Allow play user to access pcsc
  security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (subject.user == "play" && (action.id == "org.debian.pcsc-lite.access_pcsc" || action.id == "org.debian.pcsc-lite.access_card")) {
          return polkit.Result.YES;
        }
      });
  '';

}
