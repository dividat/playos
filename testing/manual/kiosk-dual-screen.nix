# Note: this test ONLY works in interactive mode because otherwise QEMU reports
# only a single connected display to the guest VM. There is probably a way to
# work around this, but could not find a way.
#
# Run using:
#   $(nix-build -A driverInteractive kiosk-dual-screen.nix)/bin/nixos-test-driver --no-interactive
let
  pkgs = import ../../pkgs { };
  serverPort = 8080;
  kioskUrl = "http://localhost:${toString serverPort}/";
  kiosk = import ../../kiosk {
    pkgs = pkgs;
    system_name = "PlayOS";
    system_version = "1.0.0";
  };
  sessionName = "kiosk-browser";
  inherit (builtins) toString;
in
pkgs.nixosTest {
  name = "Kiosk gracefully switches between output screens and modes";

  nodes.machine = { config, ... }: {
      imports = [
        (pkgs.importFromNixos "tests/common/user-account.nix")
      ];

      virtualisation.qemu.options = [
        "-enable-kvm"
        "-device" "virtio-vga,max_outputs=2"
      ];

      services.static-web-server.enable = true;
      services.static-web-server.listen = "[::]:8080";
      services.static-web-server.root = "/tmp/www";
      systemd.tmpfiles.rules = [
          "d ${config.services.static-web-server.root} 0777 root root -"
      ];

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
        };
     };
     services.displayManager = {
       # Always automatically log in play user
       autoLogin = {
         enable = true;
         user = "alice";
       };

       defaultSession = sessionName;
     };
  };

  extraPythonPackages = ps: [
    ps.colorama
    ps.types-colorama
    ps.diffimg
  ];

  #enableOCR = true;

  testScript = ''
    ${builtins.readFile ../helpers/nixos-test-script-helpers.py}
    import diffimg # type: ignore

    def xrandr(output, params):
        return machine.succeed(f"su -c 'xrandr --output {output} {params}' alice")

    def get_dm_restarts():
        _, restarts_str = machine.systemctl("show display-manager.service -p NRestarts")
        [_, num] = restarts_str.split("NRestarts=")
        return int(num.strip())

    def get_kiosk_pid():
        kiosk_pids = machine.succeed("pgrep --full kiosk-browser | sort | head -1")
        return int(kiosk_pids.strip())

    machine.start()

    machine.wait_for_file("/tmp/www")
    machine.succeed("""cat << EOF > /tmp/www/index.html
    <html>
        <body style="margin: 10px; background-color: #FFFFFF;">
            <div style="width: 100%; height: 100%; background-color: #EEEBBB;">
            <h1>Hello world</h1>
            </div>
        </body>
    </html>
    EOF""")

    machine.wait_for_unit("graphical.target")
    machine.wait_for_file("/home/alice/.Xauthority")

    # machine.wait_for_text("Hello world", timeout=20)
    # OCR does not work, for whatever reason, so instead we just sleep
    time.sleep(10) # give time for Chromium to start

    original_kiosk_pid = get_kiosk_pid()

    with TestCase("kiosk gracefully responds to screen and mode changes") as t,\
            tempfile.TemporaryDirectory() as d:
        xrandr("Virtual-1", "--primary --mode 640x480")
        time.sleep(3) # give controller time to resize

        # note: QEMU always captures only the Virtual-1 display
        machine.screenshot(d + "/screen1.png")

        xrandr("Virtual-2", "--mode 800x600")
        xrandr("Virtual-1", "--off") # kiosk used to crash here pre-fix

        xrandr("Virtual-1", "--primary --mode 640x480")
        machine.screenshot(d + "/screen2.png")

        diff = diffimg.diff(d + "/screen1.png", d + "/screen2.png")

        # sleep to ensure kiosk is finished with dumping core if crashed
        time.sleep(20)

        t.assertEqual(original_kiosk_pid, get_kiosk_pid(),
            "Kiosk PIDs do not match, it crashed - check logs.")
        t.assertEqual(0, get_dm_restarts(),
            "display manager was restarted, it crashed - check logs!")
        t.assertLess(diff, 10 / (640 * 480.0), # allow at most 10 pixels to differ
            "Initial and final screenshots do not match!")
'';
}

