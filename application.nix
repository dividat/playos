rec {
    fullProductName = "Dividat PlayOS";
    safeProductName = "playos";
    version = "2025.3.1";

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
    ];

    module = { config, lib, pkgs, ... }:
    let
      sessionName = "kiosk-browser";

      selectDisplay = pkgs.writeShellApplication {
        name = "select-display";
        runtimeInputs = with pkgs; [
          gnugrep
          gawk
          xorg.xrandr
          bash
        ];
        text = (builtins.readFile ./application/select-display.sh);
      };
    in {

      imports = [
        ./application/playos-status.nix
        ./application/power-management/default.nix
        ./application/limit-vtes.nix
      ];

      assertions = with lib; [
        { assertion = lists.any
            (persistentFolder: strings.hasPrefix persistentFolder config.playos.networking.watchdog.configDir)
            (builtins.attrNames config.playos.storage.persistentFolders);
          message = "playos.networking.watchdog.configDir must be a sub-folder of one of playos.storage.persistentFolders";
        }
      ];

      boot.blacklistedKernelModules = [
        # Blacklist NFC modules conflicting with CCID/PCSC
        # https://ludovicrousseau.blogspot.com/2013/11/linux-nfc-driver-conflicts-with-ccid.html
        "pn533_usb"
        "pn533"
        "nfc"

        # Disable any USB sound cards to create a closed world where the audio
        # landscape on the standard devices is completely predictable.
        "snd_usb_audio"
      ];

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

      # Limit virtual terminals that can be switched to
      # Virtual terminal 7 is the kiosk, 8 is the status screen
      playos.xserver.activeVirtualTerminals = [ 7 8 ];

      # System-wide packages
      environment.systemPackages = with pkgs; [ breeze-contrast-cursor-theme ];

      # Avoid bloating system image size
      services.speechd.enable = false;

      # Kiosk session
      services.xserver = {
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

              # Select best display to output to
              ${selectDisplay}/bin/select-display || true

              # Localization for xsession
              if [ -f /var/lib/gui-localization/lang ]; then
                export LANG=$(cat /var/lib/gui-localization/lang)
              fi
              if [ -f /var/lib/gui-localization/keymap ]; then
                setxkbmap $(cat /var/lib/gui-localization/keymap) || true
              fi

              # Enable Qt WebEngine Developer Tools (https://doc.qt.io/qt-6/qtwebengine-debugging.html)
              export QTWEBENGINE_REMOTE_DEBUGGING="127.0.0.1:3355"

              ${pkgs.playos-kiosk-browser}/bin/kiosk-browser \
                ${config.playos.kioskUrl} \
                http://localhost:3333/

              waitPID=$!
            '';
          }];
        };

        displayManager = {
          lightdm = {
            enable = true;
            greeter.enable = false;
            autoLogin.timeout = 0;
          };

          sessionCommands = ''
            ${pkgs.xorg.xrdb}/bin/xrdb -merge <<EOF
              Xcursor.theme: ${pkgs.breeze-contrast-cursor-theme.themeName}
            EOF
          '';
        };
      };
      services.displayManager = {
        # Always automatically log in play user
        autoLogin = {
          enable = true;
          user = "play";
        };

        defaultSession = sessionName;
      };
      # Hide mouse cursor when not in use
      services.unclutter-xfixes = {
        enable = true;
        timeout = 10;
        threshold = 1;
        extraOptions = [ "start-hidden" ];
      };

      # Firewall configuration
      networking.firewall = {
        enable = true;

        # Allow use of TFTP client for Senso firmware update
        connectionTrackingModules = [ "tftp" ];
        extraCommands = ''
          iptables --table raw --append OUTPUT --protocol udp --dport 69 --jump CT --helper tftp
        '';
      };

      # Driver service
      systemd.services."dividat-driver" = {
        description = "Dividat Driver";
        # Run driver with permissible origin limited to the origin of the kiosk URL
        serviceConfig.ExecStart = ''
          /bin/sh -c '${pkgs.dividat-driver}/bin/dividat-driver --permissible-origin $(echo "${config.playos.kioskUrl}" | grep -oP "^[^:]+://[^/]+")'
        '';
        serviceConfig.User = "play";
        wantedBy = [ "multi-user.target" ];
      };

      # Monitor hotplugging
      services.udev.extraRules = ''
        ACTION=="change", SUBSYSTEM=="drm", RUN+="${pkgs.systemd}/bin/systemctl start select-display.service"
      '';
      systemd.services."select-display" = {
        description = "Select best display to output to";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${selectDisplay}/bin/select-display";
          User = "play";
        };
        environment = {
          XAUTHORITY = "${config.users.users.play.home}/.Xauthority";
          DISPLAY = ":0";
        };
        after = [ "graphical.target" ];
      };

      # Audio
      services.pipewire.enable = false;

      hardware.pulseaudio = {
        enable = true;
        extraConfig = ''
          # Use HDMI output
          set-card-profile 0 output:hdmi-stereo
          # Respond to changes in connected outputs
          load-module module-switch-on-port-available
          load-module module-switch-on-connect blacklist=""
        '';
      };

      # Enable avahi for Senso discovery
      services.avahi.enable = true;

      # Enable pcscd for smart card identification
      services.pcscd.enable = true;
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
        network = "a09acf02330ccc60";
        authorizedKeys = [
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDUOwaIpDOHaADuJaS6+bSsEJDvmzRfdkhi8k/infDZimdbSRQvSdbRiRJlPPAeETRaKH8z5eOCJPYLSb3+EHn7oQFsUD6c5Gg+LQAahB/lhja7RoDCPH6/hHaOKYJny5lDfJ+KVSn3fNFiJ0mFJRIjGcoUeI95Rw1PHZJae8ZOapU336Uyy8hB84lvcaFmjzMEIyDkvSxpTrD+RpugG3XJhQE24a6t7fN9z3P6CfprVyFVHA3dkmxAvcYseeXA6TBfIGUbiC3wN1o7GoAgnsiVpwq9q4Ye3jMoRvB3Iw05rvcO/m5WT3JmCAWgeIM1yvWM3Pxc05E7g1jXRaygb0VVk8QendNZt+jlwVVU5N2H+LJ+vwyt+6PCFRGjPkLHjFwpoiLc7S6gHFQH4PcynyjOyAIKvBekn3LxV9hGkadVx7PwXX3C4Eqj4MGaVa095eVdtxZbSdwtUiOclXgA3G3O6Jen/fZDd2hMbX2mXgnGtn9LQjIz8RWFnyg6EU4ZfVhDsZcp8kVznQK8ibax2I++leJfVr95JsCPvVSIwNfxPA1/BDggxiwCSKUq/EvQyZ3/0pHJc3Lfca/1aTb0Hn1q5RPXjUGLlOOnG/yfD/FV1rnF49TgNIESF3tZ852Ba9sbcJohCgSCRBBeAiE7TXM5K84/V1HXlQlmA8JIJfyUlQ== openpgp:0x01C16138"
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC3XUgkqHDD9BLPBx2HbXigdRSsVXjsXaqVyJrIKIW1msdHD3BpqxYeGfXOc+yrXmOCSVHR+YJbSxiz5TR0tqo5n7hjydIIU+WLtSFrnVHmwVLojhwlW2uLDPfRbmlWM2hOE3Z6gPh04j6ks9cK3RbGQl3HnzbwWEPgIqqb7TAGAFkWtiRvPKB4P3CNwPS8AYpx5sZH6zHIr1vpp3PdFI1hyvPZVRiwCcRvTg4C13gFheHZe/ZngttJz9iMG4Lg0cpjaW7arUZxgeFNKqkJd6J6ffJxQHSkTI1jsV+sqC1OczkaDvZ6L9jHyEceoTJC67Y03tKv4ZeMgHGCapzvkHWuDqQEjk5iDF4+CRj/G7/uWN7VNLnO0SBC9FIghx8m3ES1nZJnn1TBAxRMObi+/LMcCC3EHfimY/lhreYjJuRJGlVgXygJ+Vjz7ja5Lj4/3NUGm3OBFVuvasrHc9tXKnitWH8B+BbU3uPsm15QoUlVcHbqTZGC35nn4iqbV+jKm0aLkPzzSBn9gbG4XKaK9khH6E5gJhq2do50QbfnLaUGwwVg1DKumdkzRsNEAZzjjlPGxVmvc2HPWk4xevLR0ynGuf4BSzvnCchqrh1L7uIQYOYjJR191ApPFJQ9O4ydd9WboXg/uKFSkKWHE0uzZ2uy+jbx8gHwQrKqCWzxKh6uww== openpgp:0xEC33A79F"
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

      playos.hardening.enable = true;

    };
}
