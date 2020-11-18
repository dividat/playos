{ config, pkgs, ... }:

{

  # Kiosk runs as a non-privileged user
  users.users.play = {
    isNormalUser = true;
    home = "/home/play";
    # who can play audio.
    extraGroups = [ "audio" ];
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

    displayManager.defaultSession = "kiosk-browser";

    desktopManager = {
      xterm.enable = false;
      session = [
        { name = "kiosk-browser";
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

  # Enable audio
  hardware.pulseaudio.enable = true;

  # Run PulseAudio as System-Wide daemon. See [1] for why this is in general a bad idea, but ok for our case.
  # [1] https://www.freedesktop.org/wiki/Software/PulseAudio/Documentation/User/WhatIsWrongWithSystemWide/
  hardware.pulseaudio.systemWide = true;

  # Install a command line mixer
  # TODO: remove when controlling audio works trough controller
  environment.systemPackages = with pkgs; [
    pamix
    pamixer
    breeze-contrast-cursor-theme
  ];

  # Enable avahi for Senso discovery
  services.avahi.enable = true;

  # Enable pcscd for smart card identification
  services.pcscd.enable = true;
  # Blacklist NFC modules conflicting with CCID (https://ludovicrousseau.blogspot.com/2013/11/linux-nfc-driver-conflicts-with-ccid.html)
  boot.blacklistedKernelModules = [ "pn533_usb" "pn533" "nfc" ];

}
