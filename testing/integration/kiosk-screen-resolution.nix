# See ../manual/kiosk-dual-screen.nix for a test with two output displays that
# can be run in interactive mode.
let
  pkgs = import ../../pkgs { };
  serverPort = 8080;
  kioskUrl = "http://localhost:${toString serverPort}/";
  kiosk = import ../../kiosk {
    pkgs = pkgs;
    system_name = "PlayOS";
    system_version = "1.0.0";
  };
  inherit (builtins) toString;
in
pkgs.nixosTest {
  name = "Kiosk gracefully switches between output modes";

  nodes.machine = { config, ... }: {
      imports = [
        (pkgs.importFromNixos "tests/common/user-account.nix")
      ];

      virtualisation.qemu.options = [
        "-enable-kvm"
      ];

      services.static-web-server.enable = true;
      services.static-web-server.listen = "[::]:8080";
      services.static-web-server.root = "/tmp/www";
      systemd.tmpfiles.rules = [
          "d ${config.services.static-web-server.root} 0777 root root -"
      ];

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

              ${kiosk}/bin/kiosk-browser \
                ${kioskUrl} ${kioskUrl}

              waitPID=$!
            '';
          }];
        };

        displayManager = {
          xserverArgs = [
            "-nocursor"
          ];
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
    import time
    import tempfile
    from collections import Counter
    from PIL import Image, ImageChops

    def num_diff_pixels(a, b):
        im1 = a.convert("RGB")
        im2 = b.convert("RGB")
        diff = ImageChops.difference(im1, im2)
        return sum((1 for p in diff.getdata() if p != (0, 0, 0)))

    def xrandr(params):
        return machine.succeed(f"su -c 'xrandr --output Virtual-1 {params}' alice")

    def get_dm_restarts():
        _, restarts_str = machine.systemctl("show display-manager.service -p NRestarts")
        [_, num] = restarts_str.split("NRestarts=")
        return int(num.strip())

    def get_kiosk_pid():
        kiosk_pids = machine.succeed("pgrep kiosk-browser | sort")
        return int(kiosk_pids.strip())

    machine.start()

    machine.wait_for_file("/tmp/www")
    # 4x4 grid = 16 divs, even col/row numbers divide resolution neatly
    divs = "<div></div>" * 16
    machine.succeed("""cat << EOF > /tmp/www/index.html
    <html>
        <head>
            <style>
            body {
                margin: 0;
                height: 100%;
                display: grid;
                grid-template-columns: repeat(4, 1fr);
                grid-template-rows: repeat(4, 1fr);
                grid-auto-flow: dense;
            }
            div:nth-child(even) {
                background: rgb(255, 255, 0);
            }
            div:nth-child(odd) {
                background: rgb(255, 0, 0);
            }
            div:nth-child(8n+5) {
                grid-column: 4;
            }
            </style>
        </head>
        <body class="grid">""" + divs + """</body>
    </html>
    EOF""")

    machine.wait_for_unit("graphical.target")
    machine.wait_for_file("/home/alice/.Xauthority")

    time.sleep(10) # give time for Chromium to start

    original_kiosk_pid = get_kiosk_pid()

    with TestCase("kiosk gracefully responds to screen and mode changes") as t,\
            tempfile.TemporaryDirectory() as d:
        xrandr("--mode 640x480")
        time.sleep(3) # give kiosk time to resize

        machine.screenshot(d + "/screen1.png")
        screen1 = Image.open(d + "/screen1.png").convert("RGB")

        # sanity check: size is correct
        t.assertEqual(screen1.size, (640, 480))

        # sanity check: only contains yellow and red pixels
        screen1_colors = Counter(screen1.getdata())
        t.assertDictEqual(
            screen1_colors,
            { (255, 255, 0): 640*480 // 2,
              (255, 0,   0): 640*480 // 2
            },
            "Expected only red and yellow colours on the screen"
        )

        # note: must have the same aspect ratio as the initial resolution
        xrandr("--mode 800x600")
        time.sleep(3) # give kiosk time to resize

        machine.screenshot(d + "/screen2.png")
        screen2 = Image.open(d + "/screen2.png")
        screen2_scaled = screen2.resize(screen1.size)

        t.assertEqual(
            num_diff_pixels(screen1, screen2_scaled),
            0,
            "Screenshots do not match after rescaling!"
        )

        xrandr("--off")
        xrandr("--mode 640x480")
        time.sleep(3) # give kiosk time to resize

        machine.screenshot(d + "/screen3.png")
        screen3 = Image.open(d + "/screen3.png")

        t.assertEqual(
            num_diff_pixels(screen1, screen3),
            0,
            "Initial and final screenshots do not match"
        )

        t.assertEqual(original_kiosk_pid, get_kiosk_pid(),
            "Kiosk PIDs do not match, it crashed - check logs.")
        t.assertEqual(0, get_dm_restarts(),
            "display manager was restarted, it crashed - check logs!")
'';
}
