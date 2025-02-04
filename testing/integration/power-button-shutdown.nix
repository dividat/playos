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

  testScript = {nodes}:
''
machine.start()
machine.wait_for_unit("multi-user.target")
machine.wait_for_console_text("Power Button")

print(machine.succeed("cat /proc/bus/input/devices"))

# Trigger ACPI shutdown command and expect shutdown
machine.send_monitor_command("system_powerdown")
machine.wait_for_console_text("Stopped target Multi-User System")

# Test script does not finish on its own after shutdown
exit(0)
'';
}
