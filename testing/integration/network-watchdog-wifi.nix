# These tests are separate from the rest of the tests in network-watchdog.nix,
# because the hostapd + wpa_supplicant behaviour seems to be quite
# non-deterministic. In particular, connman restarts in the presence of hostapd
# seem to cause an rfkill soft block, which then "breaks" wpa_supplicant and
# requires manual intervention.
let
  pkgs = import ../../pkgs { };
  bssExpirationScanCount = 3;
in
pkgs.testers.runNixOSTest {
  name = "network watchdog wifi related tests";

  nodes = {
    playos = { config, nodes, pkgs, lib, ... }: {
      imports = [
        (import ../../base/networking/watchdog {
            inherit pkgs lib config;
        })
      ];

      config = {
        networking.firewall.enable = false;

         # wifi and connman are disabled in runNixOSTest with mkVMOverride
        networking.wireless.enable = pkgs.lib.mkOverride 0 true;
        services.connman.enable = pkgs.lib.mkOverride 0 true;

        # ignore all interfaces except for wlan1 to reduce volatility
        services.connman.networkInterfaceBlacklist = [ "eth" "wlan0" ];

        # wlan1 is the client interface, wlan0 is the simulated AP
        networking.wireless.interfaces = [ "wlan1" ];

        # this is similar to the configuration in base/networking, but
        # with smaller values for quicker testing
        networking.wireless.extraConfig =
            ''
            # in seconds, does not seem to have precise effect on connman's
            # output
            bss_expiration_age=3

            bss_expiration_scan_count=${toString bssExpirationScanCount}
            '';

        # enable 802.11 simulation
        boot.kernelModules = [ "mac80211_hwsim" ];

        systemd.services.hostapd = {
            preStart = "${pkgs.util-linux}/bin/rfkill unblock all";
        };


        # wireless access points
        services.hostapd = {
          enable = true;
          radios.wlan0 = {
            band = "2g";
            channel = 0;
            networks = {
              wlan0 = {
                ssid = "test-ap-sae";
                bssid = "02:00:00:00:00:00";
                authentication = {
                  mode = "wpa3-sae";
                  saePasswords = [ { password = "reproducibility"; } ];
                };
              };
            };
          };
        };

        playos.networking.watchdog = {
            enable = true;
            checkURLs = [ "http://localhost:9999/does-not-exist" ];
            maxNumFailures = 1;
            checkInterval = 1;
            settingChangeDelay = 1;
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
''
${builtins.readFile ../helpers/nixos-test-script-helpers.py}
## == Helpers

def checkpoint_now():
    return playos.succeed("date +'%b %d %H:%M:%S.%6N'").strip()

def connman_scan_wifi():
    return playos.succeed("connmanctl scan wifi 2>&1 | grep -i 'scan completed'",
        timeout=10)


## == Setup

with TestPrecondition("PlayOS is booted and services are running "):
    playos.wait_for_unit('connman.service')
    playos.wait_for_unit('wpa_supplicant-wlan1.service')
    playos.wait_for_unit('hostapd.service')
    playos.wait_for_unit('playos-network-watchdog.service')

with TestPrecondition("connman sees the wifi AP"):
    playos.succeed("rfkill unblock all")
    playos.succeed("sleep 5 && systemctl restart wpa_supplicant-wlan1.service")
    # attempt to trigger an early rescan for faster test AP discovery
    playos.execute("sleep 5 && connmanctl scan wifi")
    # this can take a while...
    playos.wait_until_succeeds("connmanctl services | grep test-ap-sae", timeout=120)

## == Test cases

with TestCase("connman ignores wifi signal strength changes") as t:
    checkpoint = checkpoint_now()
    playos.succeed("iw dev wlan0 set txpower fixed 0")
    connman_scan_wifi()
    wait_for_logs(playos, 'Ignoring connman setting.*Strength',
        unit='playos-network-watchdog.service',
        since=checkpoint, timeout=30)

with TestCase("wifi AP temporarily disappearing does not cause watchdog setting updates") as t:
    checkpoint = checkpoint_now()
    playos.succeed("iw dev wlan0 ap stop")
    for _ in range(0, ${toString bssExpirationScanCount} - 1):
        connman_scan_wifi()
        # service still visible
        playos.succeed("connmanctl services | grep test-ap-sae")

    try:
        wait_for_logs(playos,
            'SETTING_CHANGE_DELAY',
            unit='playos-network-watchdog.service',
            since=checkpoint,
            timeout=0.1
        )
    except TimeoutError:
        pass
    else:
        t.fail("SETTING_CHANGE_DELAY was not supposed to happen!")

    # stop watchdog to have less spammy logs in the output
    playos.systemctl("stop playos-network-watchdog.service")

    # confirm the AP _does_ eventually disappear
    # Note: it takes longer than expected, maybe there's some extra caching on connman's side?
    wait_until_passes(
        lambda: playos.wait_until_succeeds(
            "connmanctl scan wifi && ! (connmanctl services | grep test-ap-sae)"
        ),
        retries=20,
        sleep=5
    )
'';
}
