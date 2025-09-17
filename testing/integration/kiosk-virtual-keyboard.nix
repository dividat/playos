# For debugging, build using `nix-build -A driverInteractive`
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
  name = "Virtual keyboard tests";

  nodes.machine = { config, ... }: {
      imports = [
        (pkgs.importFromNixos "tests/common/user-account.nix")
      ];

      virtualisation.qemu.options = [
        "-enable-kvm"
      ];

      virtualisation.graphics = pkgs.lib.mkOverride 0 true;

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

              # disable physical keyboard detection
              export PLAYOS_KEYBOARD_BLACKLIST=".*"

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
    from collections import Counter
    from PIL import Image, ImageChops

    SCREEN_WIDTH = 640
    SCREEN_HEIGHT = 480
    SCREEN_SIZE = SCREEN_WIDTH * SCREEN_HEIGHT

    # approx
    INPUT_ELEMENTS_SIZE = SCREEN_SIZE * 0.1

    KEYBOARD_FULL_WIDTH = SCREEN_WIDTH * 0.5
    KEYBOARD_FULL_HEIGHT = KEYBOARD_FULL_WIDTH * 800 / 2560
    KEYBOARD_FULL_SIZE = KEYBOARD_FULL_WIDTH * KEYBOARD_FULL_HEIGHT

    KEYBOARD_NUMERIC_SIZE = KEYBOARD_FULL_HEIGHT ** 2

    # max difference / err in pixels allowed due to:
    # - focus highlights on elements and vkb
    # - text present in input fields
    # - rounding / scaling errors
    # empirically confirmed that the diff can reach 0.7% (2437px @ 640x480)
    ERR_PIXELS = SCREEN_SIZE * 0.015

    def num_diff_pixels(a, b):
        im1 = a.convert("RGB")
        im2 = b.convert("RGB")
        diff = ImageChops.difference(im1, im2)
        return sum((1 for p in diff.getdata() if p != (0, 0, 0)))

    def xrandr(params):
        return machine.succeed(f"su -c 'xrandr --output Virtual-1 {params}' alice")

    machine.start()

    machine.wait_for_file("/tmp/www")
    machine.succeed("""cat << EOF > /tmp/www/index.html
    <html>
    <body style="display: flex; flex-direction: column; width: 200px;">
    <label>Number: <input type="number"></label>
    <input type="button" value="Do nothing">
    <label>Text: <input type="text"></label>
    <script>
      document.querySelectorAll('input').forEach(el => {
        el.addEventListener('input', e => console.error("INPUT: " + e.target.value));
      });
    </script>
    </body></html>
    EOF""")

    machine.wait_for_unit("graphical.target")
    machine.wait_for_file("/home/alice/.Xauthority")
    time.sleep(10) # give time for Chromium to start

    def make_screenshot():
        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as t:
            machine.screenshot(t.name)
            screen = Image.open(t).convert("RGB")

        return screen

    def assertScreenshotsSimilar(t, screen_a, screen_b, extra_msg=""):
        t.assertLess(
            num_diff_pixels(screen_a, screen_b),
            ERR_PIXELS,
            f"Screenshots not similar! {extra_msg}"
        )


    with TestPrecondition("kiosk displays the page") as t:
        xrandr(f"--mode {SCREEN_WIDTH}x{SCREEN_HEIGHT}")
        time.sleep(3) # give kiosk time to resize

        screen_initial = make_screenshot()

        # sanity check: size is correct
        t.assertEqual(screen_initial.size, (SCREEN_WIDTH, SCREEN_HEIGHT))

        # keyboard is not visible, screen contains mostly white pixels
        screen_initial_colors = Counter(screen_initial.getdata())
        t.assertGreater(
            screen_initial_colors[(255, 255, 255)], # white
            SCREEN_SIZE - INPUT_ELEMENTS_SIZE,
            "Screen is not mostly white, is the keyboard visible?"
        )


    with TestCase("keyboard (numeric) shows up when activated"):
        # focus first numeric input field
        machine.send_key("tab")
        time.sleep(1)

        # keyboard should not show up right away
        assertScreenshotsSimilar(t, screen_initial, make_screenshot())

        # activate keyboard
        machine.send_key("ret")
        time.sleep(1)

        screen_numeric_kbd = make_screenshot()

        t.assertGreater(
            num_diff_pixels(screen_initial, screen_numeric_kbd),
            KEYBOARD_NUMERIC_SIZE - ERR_PIXELS,
            "Screenshots too similar, virtual keyboard not displayed?"
        )


    with TestCase("keyboard (numeric) accepts input"):
        # spam a few random keys on the vkb
        machine.send_key("down")
        machine.send_key("ret")
        machine.send_key("down")
        machine.send_key("ret")
        machine.send_key("down")
        machine.send_key("ret")

        # expect at least one number successfully typed
        wait_for_logs(machine, "INPUT: [0-9]", timeout=3)
        time.sleep(1) # wait for all keys to be processed


    with TestCase("keyboard (numeric) is hidden/shown with escape/enter") as t:
        pre_close_screen = make_screenshot()

        # close vkb
        machine.send_key("esc")
        time.sleep(1)

        assertScreenshotsSimilar(t, screen_initial, make_screenshot(),
            extra_msg="Virtual keyboard failed to hide with Esc?")

        # reactivate vkb
        machine.send_key("ret")
        time.sleep(1)

        assertScreenshotsSimilar(t, pre_close_screen, make_screenshot(),
            extra_msg="Virtual keyboard not visible after reactivation with Return?")


    with TestCase("keyboard is hidden when input field is unfocused") as t:
        # focus on button, keyboard should hide
        machine.send_key("tab")
        time.sleep(1)

        assertScreenshotsSimilar(t, screen_initial, make_screenshot(),
            extra_msg="Virtual keyboard did not hide on unfocus?")


    with TestCase("keyboard (text) is activated on text field") as t:
        # focus on text field
        machine.send_key("tab")
        time.sleep(1)

        # keyboard should not show up right away
        assertScreenshotsSimilar(t, screen_initial, make_screenshot())

        # activate keyboard
        machine.send_key("ret")
        time.sleep(1)

        screen_full_kbd = make_screenshot()

        t.assertGreater(
            num_diff_pixels(screen_initial, screen_full_kbd),
            KEYBOARD_FULL_SIZE - ERR_PIXELS,
            "Screenshots too similar, virtual keyboard not displayed?"
        )

        t.assertGreater(
            num_diff_pixels(screen_numeric_kbd, screen_full_kbd),
            KEYBOARD_FULL_SIZE - KEYBOARD_NUMERIC_SIZE,
            "Screenshots too similar, virtual keyboard layout did not change?"
        )

    with TestCase("keyboard (text) accepts input") as t:
        machine.send_key("down")
        machine.send_key("ret")
        machine.send_key("right")
        machine.send_key("ret")
        machine.send_key("down")
        machine.send_key("ret")

        # expect at least one letter successfully typed
        wait_for_logs(machine, "INPUT: [a-z]", timeout=3)
        time.sleep(1) # wait for all keys to be processed


    with TestCase("keyboard (text) can be closed and reactivated") as t:
        pre_close_screen_text = make_screenshot()

        # esc button - keyboard should be gone
        # due to mysterious reasons esc does not work if sent immediatelly after
        # return, the little sleep helps
        time.sleep(1)
        machine.send_key("esc")
        time.sleep(1)

        assertScreenshotsSimilar(t, screen_initial, make_screenshot(),
            extra_msg="Virtual keyboard failed to hide with Esc?")

        # reactivate vkb
        machine.send_key("ret")
        time.sleep(1)

        assertScreenshotsSimilar(t, pre_close_screen_text, make_screenshot(),
            extra_msg="Virtual keyboard not visible after reactivation with Return?")
        time.sleep(1)

        # The test below is disabled, because it currently fails due to a
        # qtwebengine bug: re-focusing an input element with populated text
        # causes the input keyboard not to come up, because there is no
        # cursorRectangleChanged event produced.
        # See: https://bugreports.qt.io/browse/QTBUG-139601
        #
        # Note: this will NOT happen when using focus-shift + arrow keys for
        # navigation (i.e. with the remote control), because the focus change
        # does not cause the text to be selected (unlike when Tab key is used).
        # This means it will not happen in Play/controller, but can still
        # happen if (in the future) we use Tab-navigation for the captive
        # portal or if Tab-navigation is introduced through some other means.

        ## # - unfocus the text field
        ## machine.send_key("shift-tab")
        ## # - focus back to the text field, text is selected, keyboard is visible
        ## machine.send_key("tab")
        ## # - unfocus and close the keyboard
        ## machine.send_key("shift-tab")
        ## # - focus back to the text field, keyboard should become visible
        ## machine.send_key("tab")
        ## time.sleep(1)
        ## screen_refocus = make_screenshot()

        ## t.assertLess(
        ##     num_diff_pixels(screen_full_kbd, screen_refocus),
        ##     ERR_PIXELS,
        ##     "Virtual keyboard was not restored after re-focus!"
        ## )
'';
}
