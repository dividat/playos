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

      config = let
        allSimulatedAPInterfaces = concatMap (radio: attrNames radio.networks)
            (attrValues config.services.hostapd.radios);
        in {
         # wifi and connman are disabled in runNixOSTest with mkVMOverride
        networking.wireless.enable = mkOverride 0 true;
        services.connman.enable = mkOverride 0 true;

        # wlan1 is the client interface, wlan0* are the simulated APs
        networking.wireless.interfaces = [ "wlan1" ];

        # tell connman not to touch the simulated APs
        services.connman.networkInterfaceBlacklist =
            allSimulatedAPInterfaces;

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
            attrsets.genAttrs allSimulatedAPInterfaces (_: staticIpCfg);

        services.dnsmasq.enable = true;
        services.dnsmasq.settings = {
            interface = allSimulatedAPInterfaces;

            dhcp-option = [
                "3,10.0.9.2" # gateway, does not exist
                "6,10.0.9.3" # DNS, does not exist
            ];
            dhcp-range = "10.0.9.30,10.0.9.99,1h";
        };

        # disable the local DNS caching proxy in connman to avoid conflicts with
        # dnsmasq
        services.connman.extraFlags = [ "--nodnsproxy" ];


        # === Simulated wireless access points

        # enable 802.11 simulation
        boot.kernelModules = [ "mac80211_hwsim" ];

        systemd.services.hostapd = {
            preStart = "${pkgs.util-linux}/bin/rfkill unblock all";
        };

        # wireless access points
        services.hostapd = {
          enable = true;
          # note: do not change this to wlan1 or other id, weird failures appear
          radios.wlan0 = {
            band = "2g";
            channel = 7;
            countryCode = "US";
            networks = {
              wlan0 = {
                ssid = "test-ap-sae";
                bssid = "02:00:00:00:00:00";
                authentication = {
                  mode = "wpa3-sae";
                  saePasswords = [ { password = "reproducibility"; } ];
                };
              };
              wlan0-1 = {
                ssid = "test-ap-mixed";
                bssid = "02:00:00:00:00:01";
                authentication = {
                  mode = "wpa3-sae-transition";
                  saeAddToMacAllow = true;
                  saePasswordsFile = pkgs.writeText "password" "reproducibility";
                  wpaPasswordFile = pkgs.writeText "password" "reproducibility";
                };
              };

              # connman (tested w/ versions 1.42 and 1.43) hangs when connecting
              # to this AP, nothing in the logs neither from connman nor from
              # wpa_supplicant ¯\_(ツ)_/¯
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
                bssid = "02:00:00:00:00:03";
                authentication = {
                  mode = "none";
                };
              };

              # not functional (auth server not set up), but will show up
              # as an AP with Security = [ ieee8021x ]
              wlan0-4 = {
                ssid = "bad-ap-eap";
                bssid = "02:00:00:00:00:04";
                # cannot be empty, overriden by settings below
                authentication.mode = "none";
                settings = {
                    wpa = 3;
                    wpa_key_mgmt = "WPA-EAP";
                    auth_algs = 3;

                    ieee8021x = 1;
                    eap_server = 0;
                    auth_server_addr = "127.0.0.1";
                    auth_server_port = 1812;
                    auth_server_shared_secret = "secret";
                };
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

  testScript = {nodes}: let
    allNetworks = nodes.playos.services.hostapd.radios.wlan0.networks;
    allSSIDs = attrsets.catAttrs "ssid" (attrValues allNetworks);
    badSimulatedAPs = filter (strings.hasPrefix "bad-ap-") allSSIDs;
    goodSimulatedAPs = lists.subtractLists badSimulatedAPs allSSIDs;
  in ''
${builtins.readFile ../helpers/nixos-test-script-helpers.py}
import requests

bad_simulated_aps = set("${toString badSimulatedAPs}".split())
good_simulated_aps = set("${toString goodSimulatedAPs}".split())
all_simulated_aps = bad_simulated_aps.union(good_simulated_aps)

def wait_for_http():
    playos.wait_for_unit("playos-controller.service")
    playos.wait_until_succeeds("curl --fail http://localhost:3333/")

def service_req(service, endpoint, data=None, timeout=30):
    headers = {'Accept': 'application/json'}
    return requests.post(
        "http://localhost:13333/network/{id}/{endpoint}".format(
            id=service['id'],
            endpoint=endpoint
        ),
        data=data,
        allow_redirects=True,
        headers=headers,
        timeout=timeout
    )

def remove_req(service):
    return service_req(service, "remove")

def connect_req(service, passphrase=None):
    data = {'passphrase': passphrase} if passphrase else None
    try:
        return service_req(service, "connect", data=data)
    except Exception as e:
        print(f"Failed to connect to AP: {service['name']}")
        raise e

def find_service_by_id(service_id, service_list):
    for s in service_list:
        if s['id'] == service_id:
            return s
    return None

def find_service_by_name(name, service_list):
    for s in service_list:
        if s['name'] == name:
            return s
    return None

playos.start()

with TestPrecondition("Test APs are setup and visible to connman"):
    playos.wait_for_unit("hostapd.service")
    playos.wait_for_unit("connman.service")
    playos.wait_for_unit("playos-controller.service")
    playos.wait_for_unit("multi-user.target")

    # Wait until connman sees all the APs
    # Note: due to the wpa_supplicant restarts (from the rfkill.hook), the
    # timing is kinda unpredictable.
    # In particular the `bad-ap-blocked` seems to take an extra 10 seconds to
    # appear.
    for ap in all_simulated_aps:
        playos.wait_until_succeeds(f"connmanctl services | grep {ap}", timeout=60)

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
    for ap in all_simulated_aps:
        t.assertIn(ap, [service['name'] for service in services])

# if above passed, we know these are all visible
GOOD_SERVICES =       [s for s in services if s['name'] in good_simulated_aps]
BAD_SERVICES =        [s for s in services if s['name'] in bad_simulated_aps]
PASSPHRASE_SERVICES = [s for s in GOOD_SERVICES if s['name'] != "test-ap-open"]

EAP_SERVICE = find_service_by_name("bad-ap-eap", BAD_SERVICES)

with TestCase("controller can connect to all good APs") as t:
    for service in GOOD_SERVICES:
        passphrase = None if service['name'] == "test-ap-open" else 'reproducibility'
        r = connect_req(service, passphrase=passphrase)
        r.raise_for_status()
        output = r.json()
        out_services = output['services']
        found = find_service_by_id(service['id'], out_services)
        t.assertIsNotNone(found)
        t.assertEqual("Ready", found['state'])

with TestCase("controller can forget all APs") as t:
    for service in GOOD_SERVICES:
        r = remove_req(service)
        r.raise_for_status()
        output = r.json()
        out_services = output['services']
        found = find_service_by_id(service['id'], out_services)
        t.assertIsNotNone(found)
        t.assertEqual("Idle", found['state'])

with TestCase("controller produces clear errors when passphrase is incorrect") as t:
    for service in PASSPHRASE_SERVICES:
        r = connect_req(service, passphrase='incorrectpass')
        t.assertRaises(requests.exceptions.HTTPError, r.raise_for_status)
        output = r.json()
        t.assertIn("Password is not valid", output['message'])

with TestCase("controller produces clear errors when passphrase is missing") as t:
    for service in PASSPHRASE_SERVICES:
        r = connect_req(service, passphrase=None)
        t.assertRaises(requests.exceptions.HTTPError, r.raise_for_status)
        output = r.json()
        t.assertIn("Password is required", output['message'])

with TestCase("controller informs the user when auth protocol is unsupported") as t:
    r = connect_req(EAP_SERVICE, passphrase='whatever')
    t.assertRaises(requests.exceptions.HTTPError, r.raise_for_status)
    output = r.json()
    t.assertRegex(output['message'], "none of the.*protocols are supported")
    t.assertIn("Available protocols: IEEE8021x", output['message'])
  '';
}
