let
  pkgs = import ../../pkgs { };

  # sidekick is the name of the "sidecar" VM, see below
  primaryCheckUrl = "http://sidekick/check-primary.html";
  secondaryCheckUrl = "http://sidekick/check-secondary.html";
in
pkgs.testers.runNixOSTest {
  name = "TODO";

  nodes = {
    sidekick = { config, lib, pkgs, ... }: {
      config = {
        virtualisation.vlans = [ 1 ];
        networking.firewall.enable = false;

        services.static-web-server.enable = true;
        services.static-web-server.listen = "[::]:80";
        services.static-web-server.root = "/tmp/www";

        systemd.tmpfiles.rules = [
            "d ${config.services.static-web-server.root} 0777 root root -"
        ];
      };
    };

    playos = { config, nodes, pkgs, lib, ... }: {
      imports = [
        (import ../../base/networking/watchdog {
            inherit pkgs lib config;
        })
      ];


      config = {
        networking.firewall.enable = false;

        services.connman = {
          enable = pkgs.lib.mkOverride 0 true; # disabled in runNixOSTest by default

          # tell connman not to mess with VLAN 1, which is the VM<->VM
          # connection manually set up by runNixOSTest
          networkInterfaceBlacklist = [ "eth1" ];
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

## == Helpers

http_root = "${nodes.sidekick.services.static-web-server.root}"

def make_ok(endpoint_name):
    sidekick.succeed(f"echo 'OK' > {http_root}/check-{endpoint_name}.html")

def make_bad(endpoint_name):
    sidekick.succeed(f"rm {http_root}/check-{endpoint_name}.html || true")

def make_primary_ok():
    make_ok("primary")

def make_secondary_ok():
    make_ok("secondary")
    
def make_primary_bad():
    make_bad("primary")

def make_secondary_bad():
    make_bad("secondary")

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

def wait_for_watchdog_log(regex, after_cursor=None, timeout=10):
    return wait_for_logs(
        playos,
        regex,
        unit='playos-network-watchdog.service',
        after_cursor=after_cursor,
        timeout=timeout
    )

def wait_for_watchdog_state(state, after_cursor=None, timeout=10):
    return wait_for_watchdog_log(
        f'Current state: {state}',
        after_cursor=after_cursor,
        timeout=timeout)

def playos_now():
    return playos.succeed("date +'%Y-%m-%d %H:%M:%S'").strip()

## == Setup

playos.start()
sidekick.start()

with TestPrecondition("Stub HTTP server is functional"):
    sidekick.wait_for_unit('static-web-server.service')
    make_primary_ok()
    make_secondary_ok()
    sidekick.succeed("curl --fail ${primaryCheckUrl}")
    sidekick.succeed("curl --fail ${secondaryCheckUrl}")

with TestPrecondition("PlayOS is booted and services are running "):
    playos.wait_for_unit('connman.service')
    playos.wait_for_unit('playos-network-watchdog.service')

with TestPrecondition("PlayOS can reach the check URLs"):
    sidekick.succeed("curl --fail ${primaryCheckUrl}")
    sidekick.succeed("curl --fail ${secondaryCheckUrl}")

## == Test cases

with TestCase("watchdog reaches ONCE_CONNECTED state") as t:
    cursor = wait_for_watchdog_state('ONCE_CONNECTED', timeout=20)
    t.assertEqual(0, get_connman_restarts())

# it's possible that connman receives DHCP updates _after_ the watchdog
# has determined ONCE_CONNECTED and this will now cause a SETTING_CHANGE_DELAY.
# We sleep until the delay is done if that's the case
try:
    cursor = wait_for_watchdog_state('SETTING_CHANGE_DELAY', after_cursor=cursor, timeout=5)
    time.sleep(${toString nodes.playos.playos.networking.watchdog.settingChangeDelay})
except RuntimeError:
    # no SETTING_CHANGE_DELAY happened, so we just continue
    pass

make_primary_bad()
make_secondary_bad()

with TestCase("watchdog reaches DISCONNECTED state and triggers restart"):
    cursor = wait_for_watchdog_state('DISCONNECTED', after_cursor=cursor)
    time.sleep(1)
    t.assertEqual(1, get_connman_restarts())

make_secondary_ok()

with TestCase("watchdog reaches ONCE_CONNECTED state with only secondary URL good"):
    cursor = wait_for_watchdog_state('ONCE_CONNECTED', after_cursor=cursor)


with TestCase("watchdog goes into SETTING_CHANGE_DELAY after connman changes"):
    service = get_first_connman_service_name(playos)
    playos.succeed(f"connmanctl config {service} --domains whatever.local")

    cursor = wait_for_watchdog_state('SETTING_CHANGE_DELAY', after_cursor=cursor)
    cursor = wait_for_watchdog_state('ONCE_CONNECTED', after_cursor=cursor)




#out = playos.succeed("journalctl --output=short-full --unit playos-network-watchdog.service")
#print(out)
#playos.systemctl("stop playos-network-watchdog.service")
'';
}
