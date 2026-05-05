# You can run this test against a "real" page (which employs Service Workers)
# using:
#
#   nix-build -A driverInteractive \
#     --arg kioskUrl '"https://dev-play.dividat.com/"' \
#     --arg expectedText '"Login"' \
#     kiosk-recovery.nix
#   ./result/bin/nixos-test-driver --no-interactive
#
# You can set expectedText to empty string to skip the OCR check
{ kioskUrl ? "http://localhost:8080/"
, expectedText ? "Hello from Service Worker" }:
let
  pkgs = import ../../pkgs { };
  kiosk = import ../../kiosk {
    pkgs = pkgs;
    system_name = "PlayOS";
    system_version = "1.0.0";
  };
  inherit (builtins) toString;
in
pkgs.testers.runNixOSTest {
  name = "Kiosk's nuke-cache clears optional data";

  enableOCR = true;

  nodes.machine = { config, ... }: {
      imports = [
        (pkgs.importFromNixos "tests/common/user-account.nix")
      ];

      virtualisation.qemu.options = [
        "-enable-kvm"
      ];

      services.static-web-server.enable = true;
      services.static-web-server.listen = "[::]:8080";
      # serves index.html and sw.js
      services.static-web-server.root = "${./kiosk-recovery}";

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

      environment.systemPackages = with pkgs; [
        kiosk
      ];
  };

  extraPythonPackages = ps: [
    ps.playos-test-helpers
    ps.colorama
    ps.types-colorama
  ];

  testScript = ''
    from playos_test_helpers import TestPrecondition, TestCheck, wait_for_logs
    machine.start()
    machine.wait_for_unit("graphical.target")
    machine.wait_for_unit("display-manager.service")

    PATHS_TO_NUKE = [
      "/home/alice/.cache/kiosk-browser",
      "/home/alice/.local/share/kiosk-browser/QtWebEngine/Default/Service Worker"
    ]
    EXPECTED_TEXT = "${expectedText}"

    with TestPrecondition("kiosk-browser uses the expected cache / SW paths"):
      for path in PATHS_TO_NUKE:
        machine.wait_for_file(f"'{path}'", timeout=10)


    machine.systemctl("stop display-manager.service")

    out = machine.succeed("su - alice -c nuke-cache")
    print(out)

    with TestCheck("nuke-cache removed the expected cache / SW paths"):
      for path in PATHS_TO_NUKE:
        machine.fail(f"ls -l '{path}'")

    with TestCheck("kiosk is able to start after the removal"):
      machine.systemctl("start display-manager.service")
      machine.wait_for_unit("display-manager.service")
      machine.systemctl("is-active display-manager.service")
      machine.systemctl("is-active user-1000.session")

    with TestCheck("loading the page produced no unexpected errors from JS") as t:
      try:
        # these are produced in kiosk-recovery/index.html for unexpected paths,
        # so should not be present
        out = wait_for_logs(machine, "JS-TEST-ERR", timeout=1)
        t.fail(f"JS-TEST-ERR errors present: {out}")
      except TimeoutError:
        pass

    if EXPECTED_TEXT:
      with TestCheck(f"Page displays '{EXPECTED_TEXT}'"):
        machine.wait_for_text(EXPECTED_TEXT, timeout=5)
'';
}
