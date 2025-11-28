rec {
    fullProductName = "Dividat PlayOS";
    safeProductName = "playos";
    version = "2026.1.0";

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


    max-browser-cache-size = 1024*1024*250; # 250MB, in bytes, not including profile

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
        ./application/trim.nix
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
          "input" # Access to /dev/input for detecting keyboards in kiosk
        ];
      };

      # Note that setting up "/home" as persistent fails due to https://github.com/NixOS/nixpkgs/issues/6481
      playos.storage.persistentFolders."/home/play" = {
        mode = "0700";
        user = "play";
        group = "users";
      };

      playos.monitoring.enable = true;
      playos.monitoring.extraServices = [ "dividat-driver.service" ];

      systemd.services.telegraf.path = with pkgs; [ procps ]; # pgrep for procstat

      # track the memory and cpu usage of processes started in the X11 session
      # (kiosk, qtwebengine and anything else)
      services.telegraf.extraConfig = {
        inputs.procstat = [{
          properties = [ "cpu" "memory" ];

          taginclude = [ "process_name" ]; # not unique!
          fieldinclude = [
            "pid" # Note: PID is a field, not a tag, to avoid tag cardinality
                  # growth due to restarts.
            "cpu_time_iowait"
            "cpu_usage"
            "memory_rss"
            "memory_shared"
          ];

          filter = [{
            name = "session-procs";
            cgroups = [ "/sys/fs/cgroup/user.slice/user-*.slice/session-*.scope" ];
            users = [ "play" ];
          }];

        }];

        processors.strings = [{
          left = [{
            tag = "process_name";
            width = 64; # trim process_names to at most 64 chars to avoid very long tag names
          }];
        }];

      };

      # Limit virtual terminals that can be switched to
      # Virtual terminal 7 is the kiosk, 8 is the status screen
      playos.xserver.activeVirtualTerminals = [ 7 8 ];

      # System-wide packages
      environment.systemPackages = with pkgs; [ breeze-contrast-cursor-theme playos-diagnostics ];

      # Avoid bloating system image size
      services.speechd.enable = false;

      # Mesa shader cache does not seem to grow above a couple of MB in
      # practice, but protect against accidents.
      environment.variables.MESA_SHADER_CACHE_MAX_SIZE = "50M";

      # Kiosk session
      services.xserver = {
        enable = true;

        desktopManager = {
          xterm.enable = false;
          session = [{
            name = sessionName;
            bgSupport = true; # We don't need wallpaper management tools
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
                --max-cache-size ${toString max-browser-cache-size} \
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
      systemd.services."select-display" = let
        PlayXauthorityFile = "${config.users.users.play.home}/.Xauthority";
      in
      {
        description = "Select best display to output to";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "-${selectDisplay}/bin/select-display";
          User = "play";
          Restart = "no";
        };
        unitConfig = {
          ConditionFileNotEmpty = PlayXauthorityFile;
        };
        environment = {
          XAUTHORITY = PlayXauthorityFile;
          DISPLAY = ":0";
        };
        after = [ "graphical.target" ];
        requisite = [ "display-manager.service" ];
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
      # Mark network services with discoverable Sensos
      playos.controller.annotateDiscoveredServices = [ "_sensoControl._tcp" "_sensoUpdate._udp" ];

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
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDy1Oevsq3OEHyhOTXc7RwsIMEuqANnrHPwpI3oe+7ySnBtIWNJsK0tbrhW+qVOplnCMyFYHOHGxTesvWf3s+3mlIazCEpN3tpWO3rv+VwuV53tXovqRW8TyddEcVcjSVWcNwgVkFXeSgKvNLhOWf5u8K3JFcZjnSBdjlVJhm6haS7QUn69ZPZdHNK2sK/zwFPLwKo5ms59oBGVSXRWBMlzVsm8WMjiW53SDrGHuZ10iKc3volKdNmxuYfu5/OcG6bFSgtrUwLs/WbPhIQeXS2VDEd+wHm12ymzCL9zdgRl1DE31f+vvxs9wQnFJhijz6tVMr5/Ieqfkgxenvy3UqwEUAlyHm+0E3SjN9M/d1P9AQ5cSEHobOsEmGWxavlFGYkty0OZmaD9GtWvPXhPLevDcrwcxVmtxEhPYidQDFOXe2R5NhvEqFe4BUenb4tijJ54/tciOnLQa4+qJu6+35+7ptpEsW+U0WO1OokkBgfHLiqDPdmao8tAnCFrAGCtYINVRbdDGhMYaVXk/jYjyaw4jJ36lSVTsRhsWEz6JvAcy8LsLT3VYIlnyvdBPpT52ywpuFOE7+1ozImSFs68pHPgm1NbEIh8KobXTyGMzsw1rGRrULYX3Npx5yhA9TNU421+Bhy1afLYyBwoGIbabUbKx9psGULvGGpitdYTFFm8hQ== openpgp:0x25210E82"
	  "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDDYxWasJgE0JppjFE9s/c28MiUPew/8usdmYrq+X87yH3PA2QwffWNef0zyLCU+4qSGmVldCGAFedWjz7iONcPn4efXegNoS14mUsyapQ86MQRJcPEUOKbbMLZKcJMGgjsl0am5YOGGlFEcoj7Qs2O3yHORPi/xWsm5qT7RR7UPW+S7DQ0juU2dtPlkbg4HGzVQNCtswOWuQRmT4zbwIwLu1eUKtf5UKyHdn97stgfN1I/x0g3Jmkg2f2CKMMGdj/5WYRsaPJiHzUE7z/ZkmhCPBhh+dviMs7ZGt8dWOadlwg2dohJCV/aUHQU+TUJlz5y0M2X7J6KAl25q/j85ui4++xrzL4kao/hiIO/NNnr4ITOrm7HzHKIQov2eMUf+LPhIFBR8vO6Wy5k5At/TLnl4NZyVIjxAt7FKW7zVjWpHN7t+p8Mb/ij6QsflIAp/ESRwnqBu06aevCKamOA9l8JvDHHqqpa1p8tNEI7G2Gzab7y2j53pf7WiTfyRDdh9PnzAQcIVdRyWZAxai03ZQEm/aUVLx0Q449eUUlociF/zANaCljuSPwRd7rtPNIShxE0GY7wkq3kMPCBCAiEegGslRLcWhPykKdn4/IYt7bKsGzGBoKgq0+oKSZTIKL9iUIaipjZQtZqsHvWc6UI5K6xz2bRXrz2//gsRorMRVAmTw== openpgp:0xA5241DB2"
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
        SystemMaxUse=750M
      '';

      # Set a low default timeout when stopping services, to prevent the Windows 95 shutdown experience
      systemd.extraConfig = "DefaultTimeoutStopSec=15s";

      playos.hardening.enable = true;

    };
}
