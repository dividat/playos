let
  pkgs = import ../../pkgs { };

  checkServerIP = "10.0.2.88";
  checkServerPort = 13838;
  checkBaseURL = "http://${checkServerIP}:${toString checkServerPort}";
  primaryCheckUrl = "${checkBaseURL}/check-primary.html";
  secondaryCheckUrl = "${checkBaseURL}/check-secondary.html";
in
pkgs.testers.runNixOSTest {
  name = "TODO";

  nodes = {
    playos = { config, nodes, pkgs, lib, ... }: {
      imports = [
        (import ../../base/networking/watchdog {
            inherit pkgs lib config;
        })
      ];


      config = {
        virtualisation.forwardPorts = [
            # Forward check server IP from VM to build sandbox
            {   from = "guest";
                guest.address = checkServerIP;
                guest.port = checkServerPort;
                host.address = "127.0.0.1";
                host.port = checkServerPort;
            }
        ];
        networking.firewall.enable = false;

        services.connman = {
          enable = pkgs.lib.mkOverride 0 true; # disabled in runNixOSTest by default
        };

        playos.networking.watchdog = {
            enable = true;
            checkURLs = [
                primaryCheckUrl
                secondaryCheckUrl
            ];
            maxNumFailures = 3;
            checkInterval = 1;
            settingChangeDelay = 5;
            debug = true;
        };
      };
    };
  };

  extraPythonPackages = ps: [
    ps.colorama
    ps.types-colorama
  ];

  testScript = {nodes}:
''
${builtins.readFile ../helpers/nixos-test-script-helpers.py}
import time
import pathlib
from enum import auto, StrEnum

## == Helpers

class Endpoint(StrEnum):
    PRIMARY = auto()
    SECONDARY = auto()


class StubServer:
    def __init__(self):
        self.http_root = run_stub_server(${toString checkServerPort})

    def _endpoint_file(self, endpoint: Endpoint):
        return pathlib.Path(f"{self.http_root}/check-{endpoint}.html")

    def make_ok(self, endpoint: Endpoint):
        self._endpoint_file(endpoint).write_text("OK")

    def make_bad(self, endpoint: Endpoint):
        self._endpoint_file(endpoint).unlink()

    def make_all_ok(self):
        for e in Endpoint:
            self.make_ok(e)

    def make_all_bad(self):
        for e in Endpoint:
            self.make_bad(e)


def get_connman_restarts():
    # This counts both systemd and user-initiated restarts, unlike NRestarts from
    # `systemctl show`
    # once updated to systemd v257, can be simplified to `journalctl --list-invocations`
    num_starts_str = playos.succeed("""
        journalctl -o json --unit connman.service \
            | grep -o -P '"_SYSTEMD_INVOCATION_ID":.*?,' \
            | sort | uniq | wc -l
    """.strip())
    return int(num_starts_str.strip()) - 1

def wait_for_watchdog_log(regex, since=None, timeout=10):
    return wait_for_logs(
        playos,
        regex,
        unit='playos-network-watchdog.service',
        since=since,
        timeout=timeout
    )

def wait_for_watchdog_state(state, since=None, timeout=10):
    return wait_for_watchdog_log(
        f'Current state: {state}',
        since=since,
        timeout=timeout)
## == Setup

stub = StubServer()
playos.start()

with TestPrecondition("Stub HTTP server is functional"):
    stub.make_all_ok()
    playos.wait_for_unit("network-online.target")
    playos.succeed("curl --fail ${primaryCheckUrl}")
    playos.succeed("curl --fail ${secondaryCheckUrl}")

with TestPrecondition("PlayOS is booted and services are running "):
    playos.wait_for_unit('connman.service')
    playos.wait_for_unit('playos-network-watchdog.service')

with TestPrecondition("PlayOS can reach the check URLs"):
    playos.succeed("curl --fail ${primaryCheckUrl}")
    playos.succeed("curl --fail ${secondaryCheckUrl}")

## == Test cases

with TestCase("watchdog reaches ONCE_CONNECTED state") as t:
    checkpoint = wait_for_watchdog_state('ONCE_CONNECTED', timeout=20)
    t.assertEqual(0, get_connman_restarts())

# it's possible that connman receives DHCP updates _after_ the watchdog
# has determined ONCE_CONNECTED and this will now cause a SETTING_CHANGE_DELAY.
# We sleep until the delay is done if that's the case
try:
    checkpoint = wait_for_watchdog_state('SETTING_CHANGE_DELAY', since=checkpoint, timeout=5)
    time.sleep(${toString nodes.playos.playos.networking.watchdog.settingChangeDelay})
except RuntimeError:
    # no SETTING_CHANGE_DELAY happened, so we just continue
    pass

stub.make_all_bad()

with TestCase("watchdog reaches DISCONNECTED state and triggers restart"):
    checkpoint = wait_for_watchdog_state('DISCONNECTED', since=checkpoint)
    time.sleep(1)
    t.assertEqual(1, get_connman_restarts())

stub.make_ok(Endpoint.SECONDARY)

with TestCase("watchdog reaches ONCE_CONNECTED state with only secondary URL good"):
    checkpoint = wait_for_watchdog_state('ONCE_CONNECTED', since=checkpoint)


with TestCase("watchdog goes into SETTING_CHANGE_DELAY after connman changes"):
    service = get_first_connman_service_name(playos)
    playos.succeed(f"connmanctl config {service} --domains whatever.local")

    checkpoint = wait_for_watchdog_state('SETTING_CHANGE_DELAY', since=checkpoint)
    checkpoint = wait_for_watchdog_state('ONCE_CONNECTED', since=checkpoint)
'';
}
