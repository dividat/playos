let
  pkgs = import ../../pkgs { };
in
pkgs.testers.runNixOSTest {
  name = "ACPI power button handling";

  nodes = {
    machine = { config, pkgs, ... }: {
      imports = [ ../../application/power-management ];
    };
  };

  extraPythonPackages = ps: [
    ps.colorama
    ps.types-colorama
  ];

  testScript = {nodes}:
''
${builtins.readFile ../helpers/nixos-test-script-helpers.py}

with TestPrecondition("Power Button has been recognized"):
    machine.start()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_console_text("Power Button")

    print(machine.succeed("cat /proc/bus/input/devices"))

with TestCase("Short press on power and sleep from regular keyboard are ignored"):
    # https://github.com/qemu/qemu/blob/master/pc-bios/keymaps/en-us
    machine.send_monitor_command("sendkey 0xde") # XF86PowerOff
    machine.send_monitor_command("sendkey 0xdf") # XF86Sleep
    time.sleep(5)
    machine.succeed("echo still alive", timeout=1)

with TestCase("ACPI shutdown command invokes shutdown"):
    machine.send_monitor_command("system_powerdown")
    machine.wait_for_console_text("Stopped target Multi-User System")

# Test script does not finish on its own after shutdown
exit(0)
'';
}
