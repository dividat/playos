{ config, pkgs, lib, ... }:
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

    desktopManager = {
      xterm.enable = false;
      default = "kiosk-browser";
      session = [
        { name = "kiosk-browser";
          start = ''
            # Disable screen-saver control (screen blanking)
            xset s off

            ${pkgs.playos-kiosk-browser}/bin/kiosk-browser \
              https://play.dividat.com/ \
              http://localhost:3333/gui

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

  # Enable audio
  hardware.pulseaudio.enable = true;

  # Run PulseAudio as System-Wide daemon. See [1] for why this is in general a bad idea, but ok for our case.
  # [1] https://www.freedesktop.org/wiki/Software/PulseAudio/Documentation/User/WhatIsWrongWithSystemWide/
  hardware.pulseaudio.systemWide = true;

  # Install a command line mixer
  # TODO: remove when controlling audio works trough controller
  environment.systemPackages = with pkgs; [ pamix pamixer ];

  # Enable avahi for Senso discovery
  services.avahi.enable = true;

  # Enable pcscd for smart card identification
  services.pcscd.enable = true;

}
