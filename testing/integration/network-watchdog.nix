let
  pkgs = import ../../pkgs { };

  proxyPort = 8888;
  proxyUser = "user";
  proxyPassword = "muchsecure";
  proxyURI = "http://${proxyUser}:${proxyPassword}@127.0.0.1:${toString proxyPort}/";

  checkServerIP = "10.0.2.88";
  checkServerPort = 13838;
  checkBaseURL = "http://${checkServerIP}:${toString checkServerPort}";

  primaryCheckUrl = "${checkBaseURL}/check-primary.html";
  secondaryCheckUrl = "${checkBaseURL}/check-secondary.html";
in
pkgs.testers.runNixOSTest {
  name = "network watchdog integration tests";

  nodes = {
    playos = { config, nodes, pkgs, lib, ... }: {
      imports = [
        (import ../../base/networking/watchdog {
            inherit pkgs lib config;
        })
      ];

      config = {
        virtualisation.forwardPorts = [
            # Forward check server IP from (guest) VM to build sandbox (host)
            {   from = "guest";
                guest.address = checkServerIP;
                guest.port = checkServerPort;
                host.address = "127.0.0.1";
                host.port = checkServerPort;
            }
        ];
        networking.firewall.enable = false;

        # use in place of checkServer when proxy is enabled
        systemd.services.always-ok-http-service = {
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];
          serviceConfig = {
            ExecStart =
              let
                respond =
                    ''echo -e "HTTP/1.1 200 OK\r\n" && echo "YOU_WERE_PROXIED"'';
              in
              "${pkgs.nmap}/bin/ncat -lk -p 9999 -c '${respond}'";
            Restart = "always";
          };
        };

        services.tinyproxy = {
          enable = true;
          settings = {
            Listen = "0.0.0.0";
            Port = proxyPort;
            BasicAuth = "${proxyUser} ${proxyPassword}";
            Upstream = ''http 127.0.0.1:9999'';
          };
        };

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
            settingChangeDelay = 3;
            checkUrlTimeout = 0.2;
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
let
    watchdogCfg = nodes.playos.playos.networking.watchdog;
in
''
${builtins.readFile ../helpers/nixos-test-script-helpers.py}
import pathlib
from enum import auto, StrEnum
import datetime

## == Config vars

check_interval = ${toString watchdogCfg.checkInterval}
retries = ${toString watchdogCfg.maxNumFailures}
setting_change_delay = ${toString watchdogCfg.settingChangeDelay}
watchdog_http_req_timeout = ${toString watchdogCfg.checkUrlTimeout}

# Worst case delay: once or twice delayed due to connman setting changes + retries exhausted
max_state_change_time = setting_change_delay*2 + (retries+1)*(check_interval+watchdog_http_req_timeout)

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
        self._endpoint_file(endpoint).unlink(missing_ok=True)

    def make_all_ok(self):
        for e in Endpoint:
            self.make_ok(e)

    def make_all_bad(self):
        for e in Endpoint:
            self.make_bad(e)


def get_connman_restarts():
    # This counts both systemd and user-initiated restarts, unlike NRestarts from
    # `systemctl show`. Once updated to systemd v257, can be simplified to `journalctl --list-invocations`
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

CURRENT_CHECKPOINT = None

# Waits for watchdog to announce that it has reached `state` since
# CURRENT_CHECKPOINT checkpoint and updates CURRENT_CHECKPOINT if it does.
# Each call to this function ensures that the reached state is new, i.e.
# was reached after the previous call to `wait_for_watchdog_state`.
# Note that this will skip/ignore intermediate states.
def wait_for_watchdog_state(state, timeout=max_state_change_time):
    global CURRENT_CHECKPOINT
    timestamp = wait_for_watchdog_log(
        f'Current state: {state}',
        since=CURRENT_CHECKPOINT,
        timeout=timeout)

    # Add 1 microsecond to ensure the next `since=` will be looking strictly
    # into the future, this is crucial! Locale/timezone are ignored.
    fmt = '%b %d %H:%M:%S.%f' # journalctl --output short-precise format: Jun 19 12:21:02.068866
    time = datetime.datetime.strptime(timestamp, fmt)
    new_time = time + datetime.timedelta(microseconds=1)
    CURRENT_CHECKPOINT = new_time.strftime(fmt)


CONNMAN_RESTARTS = 0

def expect_no_new_connman_restarts(t):
    t.assertEqual(CONNMAN_RESTARTS, get_connman_restarts())

def expect_connman_restart_increment(t):
    global CONNMAN_RESTARTS
    t.assertEqual(CONNMAN_RESTARTS + 1, get_connman_restarts())
    CONNMAN_RESTARTS += 1


def wait_for_connman_restart(t):
    wait_until_passes(
        lambda: expect_connman_restart_increment(t),
        sleep=1,
        retries=3
    )

def configure_connman(flags):
    service = get_first_connman_service_name(playos)
    playos.succeed(f"connmanctl config {service} {flags}")

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
    playos.wait_for_unit('tinyproxy.service')
    playos.wait_for_unit('always-ok-http-service.service')

with TestPrecondition("PlayOS can reach the check URLs") as t:
    playos.succeed("curl --fail ${primaryCheckUrl}")
    playos.succeed("curl --fail ${secondaryCheckUrl}")
    out = playos.succeed("curl --proxy ${proxyURI} --fail ${primaryCheckUrl}")
    t.assertEqual(out.strip(), "YOU_WERE_PROXIED")


## == Test cases

with TestCase("watchdog reaches ONCE_CONNECTED state") as t:
    wait_for_watchdog_state('ONCE_CONNECTED')
    expect_no_new_connman_restarts(t)

# Note: SETTING_CHANGE_DELAY possible here if connman receives DHCP updates _after_ the
# watchdog has determined ONCE_CONNECTED. We don't care about it.

stub.make_all_bad()

with TestCase("watchdog eventually reaches DISCONNECTED state and triggers restart") as t:
    wait_for_watchdog_state('DISCONNECTED')
    wait_for_connman_restart(t)

# Note: SETTING_CHANGE_DELAY will happen here (and later due) to the connman restarts.

stub.make_ok(Endpoint.SECONDARY)

with TestCase("watchdog reaches ONCE_CONNECTED state with only secondary URL good"):
    wait_for_watchdog_state('ONCE_CONNECTED')


with TestCase("watchdog goes into SETTING_CHANGE_DELAY after connman changes") as t:
    configure_connman("--domains whatever.local")
    wait_for_watchdog_state('SETTING_CHANGE_DELAY')
    wait_for_watchdog_state('ONCE_CONNECTED')
    expect_no_new_connman_restarts(t)


# Note: this test case is "here" in the sequence, because by we know connman is
# done with configuration and there should be no more SETTING_CHANGE_DELAYs that
# affect the test timing.
with TestCase("watchdog retries with sleep according to config") as t:
    stub.make_all_bad()
    try:
        wait_for_watchdog_state('DISCONNECTED', timeout=check_interval*(retries-1))
    except TimeoutError:
        # all good, should not have reached DISCONNECTED yet
        pass
    else:
        t.fail("Reached DISCONNECTED state too soon!")

    wait_for_watchdog_state('DISCONNECTED', timeout=check_interval+1)
    wait_for_connman_restart(t)
    wait_for_watchdog_state('SETTING_CHANGE_DELAY')
    stub.make_all_ok()
    wait_for_watchdog_state('ONCE_CONNECTED')


# This test case is inspired by a real-world scenario, see:
# https://www.notion.so/dividat/PlayOS-network-connectivity-debugging-1fc6ed7e60528050a268f84009197715?source=copy_link#1fc6ed7e60528091b282f3dbfaf7db98
with TestCase("watchdog restarts connman to recover from external ip setting corruption") as t:
    playos.succeed("ip address flush dev eth0")
    wait_for_watchdog_state('SETTING_CHANGE_DELAY')
    wait_for_watchdog_state('ONCE_CONNECTED')
    wait_for_watchdog_state('DISCONNECTED')
    wait_for_connman_restart(t)
    wait_for_watchdog_state('ONCE_CONNECTED')


with TestCase("watchdog recovers after ip route flush") as t:
    playos.succeed("ip route flush dev eth0")
    wait_for_watchdog_state('SETTING_CHANGE_DELAY')
    wait_for_watchdog_state('ONCE_CONNECTED')
    wait_for_watchdog_state('DISCONNECTED')
    wait_for_connman_restart(t)
    wait_for_watchdog_state('ONCE_CONNECTED')

## Proxy tests

stub.make_all_bad()

with TestCase("watchdog detects configured proxy and uses it") as t:
    wait_for_watchdog_state('DISCONNECTED')
    wait_for_connman_restart(t)
    wait_for_watchdog_state('NEVER_CONNECTED')

    configure_connman("--proxy manual ${proxyURI}")
    wait_for_watchdog_state('SETTING_CHANGE_DELAY')
    # proxy redirects check URLs to always-ok-http-service, so it works
    wait_for_watchdog_state('ONCE_CONNECTED')

with TestCase("watchdog responds to proxy removal") as t:
    configure_connman("--proxy direct")
    wait_for_watchdog_state('SETTING_CHANGE_DELAY')
    # stub is still in make_all_bad, so we get disconnected
    wait_for_watchdog_state('DISCONNECTED')
    wait_for_connman_restart(t)
    wait_for_watchdog_state('NEVER_CONNECTED')
    stub.make_all_ok()
    wait_for_watchdog_state('ONCE_CONNECTED')


# test case for false positives - a bit synthetic
with TestCase("if connman gets misconfigured, watchdog remains disconnected after restarting connman") as t:
    service = get_first_connman_service_name(playos)
    # invalid static IP config, should make checkServerIP unreachable
    playos.succeed(f"connmanctl config {service} --ipv4 manual 172.33.33.33 255.255.255.0 172.33.33.1")

    wait_for_watchdog_state('SETTING_CHANGE_DELAY')
    wait_for_watchdog_state('ONCE_CONNECTED')
    wait_for_watchdog_state('DISCONNECTED')
    wait_for_connman_restart(t)
    wait_for_watchdog_state('SETTING_CHANGE_DELAY')
    wait_for_watchdog_state('NEVER_CONNECTED')

    try:
        wait_for_watchdog_state('ONCE_CONNECTED', timeout=check_interval*2)
    except TimeoutError:
        # all good, we were not supposed to reach this state
        pass
    else:
        t.fail("Did not expect to reach ONCE_CONNECTED state!")
'';
}
