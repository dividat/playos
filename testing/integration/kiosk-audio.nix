let
  pkgs = import ../../pkgs { };
  serverPort = 8080;
  kioskUrl = "http://localhost:${toString serverPort}/";
  kiosk = import ../../kiosk {
    pkgs = pkgs;
    system_name = "PlayOS";
    system_version = "1.0.0";
  };
  opusFile = pkgs.fetchurl {
    url = "https://github.com/dividat/game-drops/raw/refs/heads/main/static/sound/drops/success-1.opus";
    hash = "sha256-MzKOYnNnhjsnl9fQ2MGsR2vjMtZnpdXBNi5BXoLEjUY=";
  };
  inherit (builtins) toString;
in
pkgs.nixosTest {
  name = "Kiosk can play opus files";

  nodes.machine = { config, ... }: {
      imports = [
        (pkgs.importFromNixos "tests/common/user-account.nix")
      ];

      services.static-web-server.enable = true;
      services.static-web-server.listen = "[::]:${toString serverPort}";
      services.static-web-server.root = "/tmp/www";
      systemd.tmpfiles.rules = [
          "d ${config.services.static-web-server.root} 0777 root root -"
      ];
    
      # Uncomment for interactive debugging
      # virtualisation.forwardPorts = [
      #     { from = "host"; host.port = 13355; guest.port = 3355; }
      #     { from = "host"; host.port = 8080; guest.port = 8080; }
      # ];
      # networking.firewall.enable = false;

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

              export QTWEBENGINE_REMOTE_DEBUGGING="0.0.0.0:3355"
              export QTWEBENGINE_CHROMIUM_FLAGS="--enable-logging --v=stderr"

              ${kiosk}/bin/kiosk-browser \
                ${kioskUrl} ${kioskUrl}

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
            user = "alice";
          };

          defaultSession = sessionName;
        };
     };
  };

  extraPythonPackages = ps: [
    ps.colorama
    ps.types-colorama
    ps.pillow
    ps.types-pillow
  ];

  testScript = ''
    ${builtins.readFile ../helpers/nixos-test-script-helpers.py}

    machine.start()

    machine.wait_for_file("/tmp/www")
    machine.succeed("ln -s '${opusFile}' /tmp/www/demo.opus")
    machine.succeed("""cat << EOF > /tmp/www/index.html
    <html>
    <head>
    <script>
      window.onload = (ev) => {
        console.log("Ready to play");
        new Audio("/demo.opus").play()
          .then((stream) => {
             console.log("Audio was played!");
          })
          .catch((error) => {
              console.log("Error playing: " + error.toString());
          });
      };
    </script>
    </head>
    </html>
    EOF""")
    machine.wait_for_unit("graphical.target")

    with TestPrecondition("Chromium is producing logs"):
        wait_for_logs(machine, "Ready to play", timeout=40);

    with TestCase("Audio playback was succesful"):
        wait_for_logs(machine, "Audio was played", timeout=2);
'';
}
