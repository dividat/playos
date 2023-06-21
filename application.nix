rec {
    version = "2023.2.0";

    greeting = label: ''
                                           _
                                       , -"" "".
                                     ,'  ____  `.
                                   ,'  ,'    `.  `._
          (`.         _..--.._   ,'  ,'        \\    \\
         (`-.\\    .-""        ""'   /          (  d _b
        (`._  `-"" ,._             (            `-(   \\
        <_  `     (  <`<            \\              `-._\\
         <`-       (__< <           :                      ${label}
          (__        (_<_<          ;
      -----`------------------------------------------------------ ----------- ------- ----- --- -- -
    '';

    overlays = [
      (import ./application/overlays version)
      # Limit virtual terminals that can be switched to
      # Virtual terminal 7 is the kiosk, 8 is the status screen
      (import ./application/overlays/xorg { activeVirtualTerminals = [ 7 8 ]; })
    ];

    module = { config, lib, pkgs, ... }: {

      imports = [ ./application/playos-status.nix ];

      # Kiosk runs as a non-privileged user
      users.users.play = {
        isNormalUser = true;
        home = "/home/play";
        extraGroups = [
          "dialout" # Access to serial ports for the Senso flex
        ];
      };

      # Note that setting up "/home" as persistent fails due to https://github.com/NixOS/nixpkgs/issues/6481
      playos.storage.persistentFolders."/home/play" = {
        mode = "0700";
        user = "play";
        group = "users";
      };

      # System-wide packages
      environment.systemPackages = with pkgs; [ breeze-contrast-cursor-theme ];

      # Kiosk session
      services.xserver = let sessionName = "kiosk-browser";
      in {
        enable = true;

        desktopManager = {
          xterm.enable = false;
          session = [{
            name = sessionName;
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

              # We want to avoid making the user configure audio outputs, but
              # instead route audio to both the standard output and any connected
              # displays. This looks for any "HDMI" device on ALSA card 0 and
              # tries to add a sink for it. Both HDMI and DisplayPort connectors
              # will count as "HDMI". We ignore failure from disconnected ports.
              for dev_num in $(aplay -l | grep "^card 0:" | grep "HDMI" | grep "device [0-9]\+" | sed "s/.*device \([0-9]\+\):.*/\1/"); do
                printf "Creating ALSA sink for device $dev_num: "
                pactl load-module module-alsa-sink device="hw:0,$dev_num" sink_name="hdmi$dev_num" sink_properties="device.description='HDMI-$dev_num'" || true
              done
              pactl load-module module-combine-sink sink_name=combined
              pactl set-default-sink combined

              # Enable Qt WebEngine Developer Tools (https://doc.qt.io/qt-5/qtwebengine-debugging.html)
              export QTWEBENGINE_REMOTE_DEBUGGING="127.0.0.1:3355"

              ${pkgs.playos-kiosk-browser}/bin/kiosk-browser \
                ${config.playos.kioskUrl} \
                http://localhost:3333/

              waitPID=$!
            '';
          }];
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
      hardware.pulseaudio = { enable = true; };

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

      playos.remoteMaintenance = {
        enable = true;
        networks = [ "a09acf02330ccc60" ];
        authorizedKeys = [
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDUOwaIpDOHaADuJaS6+bSsEJDvmzRfdkhi8k/infDZimdbSRQvSdbRiRJlPPAeETRaKH8z5eOCJPYLSb3+EHn7oQFsUD6c5Gg+LQAahB/lhja7RoDCPH6/hHaOKYJny5lDfJ+KVSn3fNFiJ0mFJRIjGcoUeI95Rw1PHZJae8ZOapU336Uyy8hB84lvcaFmjzMEIyDkvSxpTrD+RpugG3XJhQE24a6t7fN9z3P6CfprVyFVHA3dkmxAvcYseeXA6TBfIGUbiC3wN1o7GoAgnsiVpwq9q4Ye3jMoRvB3Iw05rvcO/m5WT3JmCAWgeIM1yvWM3Pxc05E7g1jXRaygb0VVk8QendNZt+jlwVVU5N2H+LJ+vwyt+6PCFRGjPkLHjFwpoiLc7S6gHFQH4PcynyjOyAIKvBekn3LxV9hGkadVx7PwXX3C4Eqj4MGaVa095eVdtxZbSdwtUiOclXgA3G3O6Jen/fZDd2hMbX2mXgnGtn9LQjIz8RWFnyg6EU4ZfVhDsZcp8kVznQK8ibax2I++leJfVr95JsCPvVSIwNfxPA1/BDggxiwCSKUq/EvQyZ3/0pHJc3Lfca/1aTb0Hn1q5RPXjUGLlOOnG/yfD/FV1rnF49TgNIESF3tZ852Ba9sbcJohCgSCRBBeAiE7TXM5K84/V1HXlQlmA8JIJfyUlQ== openpgp:0x01C16138"
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDXvP3MLATx2TybGzQ7AtWX5NsDl8SC/sL3kTR7VefOAZzxOlCi8hQjRGiAjEqESepx5VTOtDP1p1slhwjkTsPoUmLeZxpRCZfXS4CuXmdJHJ+tLkuDtYhJm6s4lcHByzv3ErE3MGIqTPE0f0meXd1WOCCOSk8BzCot7WmqIHo0VgPMDq9Hb/NSJDnzlL4aZG2yF2hfrmPV31caKMXYCWDVCZWsSPexCmmU10kWfoAYNFzaCrLczPaTsvPNopiobnQ4cmEQk/GDaWy2fobiU9g4/iYh9czGnJNeeaFAPkcr1ivBKmD5qTS613OJwXqnaQy0+rh/HxOoXMpZYH6Hv7uXmtA2PtGTL8Fum5KnCk+M+H/8ohyPluWRVueRUK9MOzIkIvA0HlF4TdTMR+qhBY/yp2RaDg5PDwKypFqZz1RG/lAhCxtTZspqT2NdFvLfcfpT6rqlI3kt+clNTloeprudfSAKfU/rtBGT9qZjCL9CgGE2HB/RhPaBA1NsFXevvLzsJbGQ7ebaCM0Bl6mFkBqS73zqSonz1GOkWkq4tMyO7LH2iW6RHSpKDyHaY4hDmiCHEx8xEH/OlI+6xz0jcVdxe6a6YUwzjIWYi0D457aEMh+G3VAwTRa4PMoNaJe+ynvnUXC5CGsX8iOwXe4vWodLLHtBGcOhWJUNFrQ1AloDnQ== openpgp:0xA3BCEAAB"
        ];
      };

      # Enable persistent journaling with low maximum size
      playos.storage.persistentFolders."/var/log/journal" = {
        mode = "0755";
        user = "root";
        group = "root";
      };
      services.journald.extraConfig = ''
        Storage=persistent
        SystemMaxUse=1G
      '';

      # Set a low default timeout when stopping services, to prevent the Windows 95 shutdown experience
      systemd.extraConfig = "DefaultTimeoutStopSec=15s";

    };
}
