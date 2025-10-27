let
  pkgs = import ../../pkgs { };
  mkTestMachine = imports: { config, pkgs, ... }: {
    imports = imports;

    networking.wireless.enable = true;
    boot.kernelModules = [ "mac80211_hwsim" ];

    environment.systemPackages = [ pkgs.iw ];

    # This service forces power_save=on, and is set up to run before the tested service.
    systemd.services.force-wifi-power-save = {
      description = "Force WiFi Power Save ON for testing";
      after = [ "sys-subsystem-net-devices-wlan0.device" ];
      before = [ "network-pre.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStartPre = "${pkgs.iproute2}/bin/ip link set wlan0 up";
        ExecStart = "${pkgs.iw}/bin/iw dev wlan0 set power_save on";
      };
    };
 };
in
# Verify that power_save feature is disabled automatically on boot.
pkgs.testers.runNixOSTest {
  name = "WiFi power saving is disabled";

  nodes = {
    control_machine = mkTestMachine [];
    machine = mkTestMachine [ ../../base/networking/disable-wifi-powersave.nix ];
  };

  extraPythonPackages = ps: [
    ps.colorama
    ps.types-colorama
  ];

  testScript = {nodes}:
''
${builtins.readFile ../helpers/nixos-test-script-helpers.py}

start_all()

with TestPrecondition("Machine booted and force-wifi-power-save service succeeded"):
  control_machine.wait_for_unit("multi-user.target")
  machine.wait_for_unit("multi-user.target")

with TestCase("WiFi power save is enabled on control machine but disabled on target machine"):
  control_machine.succeed("iw dev wlan0 get power_save | grep 'on'")
  machine.succeed("iw dev wlan0 get power_save | grep 'off'")
'';
}


