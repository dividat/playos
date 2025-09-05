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

      users.users."alice".extraGroups = [ "input" ];

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

              # ignore the default PS/2 keyboard and the virtio added by nixosTest
              export PLAYOS_KEYBOARD_BLACKLIST="AT Translated Set 2 keyboard;QEMU Virtio Keyboard"

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
  ];

  testScript = ''
    ${builtins.readFile ../helpers/nixos-test-script-helpers.py}

    machine.start()

    machine.wait_for_unit("graphical.target")
    machine.wait_for_file("/home/alice/.Xauthority")

    checkpoint = None

    with TestCase("kiosk detects no keyboard attached"):
        checkpoint = wait_for_logs(machine, "enabling virtual keyboard", timeout=20)

    with TestCase("new keyboard device -> disable virtual keyboard"):
        machine.send_monitor_command("device_add usb-kbd,id=testkbd")
        wait_for_logs(machine, "New USB device found", since=checkpoint, timeout=5)
        checkpoint = wait_for_logs(machine, "Product: QEMU USB Keyboard", since=checkpoint, timeout=5)
        checkpoint = wait_for_logs(machine, "disabling virtual keyboard", since=checkpoint, timeout=5)

    with TestCase("keyboard device unplugged -> enable virtual keyboard"):
        machine.send_monitor_command("device_del testkbd")
        checkpoint = wait_for_logs(machine, "enabling virtual keyboard", since=checkpoint, timeout=5)
'';
}
