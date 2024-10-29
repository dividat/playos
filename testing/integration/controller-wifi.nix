let
  pkgs = import ../../pkgs { };

  updateCert = .../../pki/dummy/cert.pem;

  # url from where updates should be fetched
  updateUrl = "http://localhost:9000/";
  # url where kiosk points
  kioskUrl = "https://play.dividat.com";

  fullProductName = "playos";
  safeProductName = "playos";
  version = "1.1.1-TEST";
  greeting = s: "hello: ${s}";

  playos-controller = import ../../controller {
    inherit pkgs version updateUrl kioskUrl;
    bundleName = safeProductName;
  };
in
with builtins;
with pkgs.lib;
pkgs.testers.runNixOSTest {
  name = "Controller wifi connectivity reporting";

  nodes = {
    playos = { config, modulesPath, ... }: {
      imports = [
        (import ../../base {
          inherit pkgs kioskUrl playos-controller;
          inherit safeProductName fullProductName greeting version;
        })
        "${modulesPath}/services/networking/dnsmasq.nix"
      ];

      config = {
         # wifi and connman are disabled in runNixOSTest with mkVMOverride
        networking.wireless.enable = mkOverride 0 true;
        services.connman.enable = mkOverride 0 true;

        # wlan1 is the client interface, wlan0* are the simulated APs
        networking.wireless.interfaces = [ "wlan1" ];

        # prevent connman from touching the simulated APs
        services.connman.networkInterfaceBlacklist =
            attrNames config.services.hostapd.radios.wlan0.networks;

        # disable the local DNS caching proxy to avoid conflicts with dnsmasq
        services.connman.extraFlags = [ "--nodnsproxy" ];

        systemd.services."connman".after = [ "hostapd.service" ];

        # allow accesing controller GUI from the test runner
        networking.firewall.enable = mkForce false;
        virtualisation.forwardPorts = [
            {   from = "host";
                host.port = 13333;
                guest.port = 3333;
            }
        ];


        # === dnsmasq + static IPs for wlan0*

        # Setup networking + DHCP (dnsmasq) for the simulated wireless APs.
        # Without this connman will wait ages for a (non-existant) DHCP
        # offer, makin the tests unbearably slow.
        #
        # Note: this could probably be made to properly route traffic via the
        # test VLANs or QEMU's vnet, but for now just returns some values in
        # the 10.0.9.0/24 subnet
        networking.interfaces =
            let staticIpCfg = {
                ipv4.addresses = [{
                    address = "10.0.9.1"; # irrelevant
                    prefixLength = 24;
                }];
            };
            in
            mapAttrs (_: _: staticIpCfg)
                config.services.hostapd.radios.wlan0.networks;

        services.dnsmasq.enable = true;
        services.dnsmasq.settings = {
            interface = attrNames config.services.hostapd.radios.wlan0.networks;

            dhcp-option = [
                "3,10.0.9.2" # gateway, does not exist
                "6,10.0.9.3" # DNS, does not exist
            ];
            dhcp-range = "10.0.9.30,10.0.9.99,1h";
        };

        # === Simulated wireless access points

        # enable 802.11 simulation
        boot.kernelModules = [ "mac80211_hwsim" ];

        # wireless access points
        services.hostapd = {
          enable = true;
          radios.wlan0 = {
            band = "2g";
            countryCode = "US";
            networks = {
              wlan0 = {
                ssid = "test-ap-sae";
                authentication = {
                  mode = "wpa3-sae";
                  saePasswords = [ { password = "reproducibility"; } ];
                };
                bssid = "02:00:00:00:00:00";
              };
              wlan0-1 = {
                ssid = "test-ap-mixed";
                authentication = {
                  mode = "wpa3-sae-transition";
                  saeAddToMacAllow = true;
                  saePasswordsFile = pkgs.writeText "password" "reproducibility";
                  wpaPasswordFile = pkgs.writeText "password" "reproducibility";
                };
                bssid = "02:00:00:00:00:01";
              };
              # connman fails to connect to this one, nothing in the logs
              #wlan0-2 = {
              #  ssid = "test-ap-wpa2";
              #  authentication = {
              #    mode = "wpa2-sha256";
              #    wpaPassword = "reproducibility";
              #  };
              #  bssid = "02:00:00:00:00:02";
              #};
              wlan0-3 = {
                ssid = "test-ap-open";
                authentication = {
                  mode = "none";
                };
                bssid = "02:00:00:00:00:03";
              };
            };
          };
        };
      };
    };
  };

  extraPythonPackages = ps: [
    ps.requests
    ps.types-requests
    ps.colorama
    ps.types-colorama
  ];

  testScript = {nodes}: ''
${builtins.readFile ../helpers/nixos-test-script-helpers.py}
import requests
#import json

hostapdAPs = set("${toString (attrsets.catAttrs "ssid" (attrsets.attrValues nodes.playos.services.hostapd.radios.wlan0.networks))}".split())

def wait_for_http():
    playos.wait_for_unit("playos-controller.service")
    playos.wait_until_succeeds("curl --fail http://localhost:3333/")

playos.start()


with TestPrecondition("Test APs are setup and visible to connman"):
    playos.wait_for_unit("hostapd.service")
    playos.wait_for_unit("connman.service")
    playos.wait_for_unit("playos-controller.service")
    playos.wait_for_unit("multi-user.target")

    # Wait until connman sees all the APs 
    # Note: due to the wpa_supplicant restarts (from the rfkill.hook), the
    # timing is kinda unpredictable
    for ap in hostapdAPs:
        playos.wait_until_succeeds(f"connmanctl services | grep {ap}", timeout=20)

# === sanity check

wait_for_http()

with TestCase("controller sees the wifi iface and APs") as t:
    headers = {'Accept': 'application/json'}
    r = requests.get("http://localhost:13333/network", headers=headers)
    r.raise_for_status()
    output = r.json()
    ifaces = output['interfaces']
    t.assertIn("wlan1", [iface['name'] for iface in ifaces])

    services = output['services']
    for ap in hostapdAPs:
        t.assertIn(ap, [service['name'] for service in services])

# if above passed, we know these are all the hostapdAPs
TEST_SERVICES = [s for s in services if s['name'] in hostapdAPs]

with TestCase("controller can connect to all wifi APs") as t:
    headers = {'Accept': 'application/json'}
    data = {'passphrase': 'reproducibility'}

    for service in TEST_SERVICES:
        r = requests.post(
            "http://localhost:13333/network/{id}/connect".format(id=service['id']),
            data=(None if service['name'] == "test-ap-open" else data),
            allow_redirects=True,
            headers=headers,
            timeout=15
        )
        r.raise_for_status()
        output = r.json()
        out_services = output['services']
        ready_services = [s for s in out_services if 'Ready' in s['state']]
        t.assertIn(service['id'], [s['id'] for s in ready_services])

with TestCase("controller can forget all wifi APs") as t:
    headers = {'Accept': 'application/json'}
    for service in TEST_SERVICES:
        r = requests.post(
            "http://localhost:13333/network/{id}/remove".format(id=service['id']),
            allow_redirects=True,
            headers=headers,
            timeout=15
        )
        r.raise_for_status()
        output = r.json()
        out_services = output['services']
        idle_services = [s for s in out_services if 'Idle' in s['state']]
        t.assertIn(service['id'], [s['id'] for s in idle_services])
  '';

}
