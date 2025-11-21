let
  pkgs = import ../../pkgs { };

  updateCert = .../../pki/dummy/cert.pem;

  updateUrl = "http://localhost:9000/";
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
  name = "ConnMan retry mechanism for WPA3-SAE";

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
        services.connman = {
          enable = mkOverride 0 true;
          extraFlags = [
            # debug logging for observability
            "--debug=plugins/wifi.c,src/service.c,src/storage.c"
            # disable the local DNS caching proxy in connman to avoid conflicts with dnsmasq
            "--nodnsproxy"
          ];
          # tell connman not to touch the simulated APs
          networkInterfaceBlacklist = allSimulatedAPInterfaces;
        };

        virtualisation.vlans = mkOverride 0 [ ];

        # wlan1 is the client interface, wlan0* are the simulated APs
        networking.wireless.interfaces = [ "wlan1" ];

        # allow accesing controller GUI from the test runner
        networking.firewall.enable = mkForce false;
        virtualisation.forwardPorts = [
            { from = "host"; host.port = 13333; guest.port = 3333; }
        ];

        # create service config with wifi as favorite but incorrect password
        systemd.services.provision-connman-wifi = {
            wantedBy = [ "multi-user.target" ];
            before = [ "connman.service" ];
            serviceConfig.Type = "oneshot";
            # The ID/path format is `wifi_<mac>_<hex of ssid>_managed_psk`
            script = ''
              mkdir -p /var/lib/connman/wifi_02deadbeef01_746573742d61702d736165_managed_psk

              cat > /var/lib/connman/wifi_02deadbeef01_746573742d61702d736165_managed_psk/settings <<EOF
              [wifi_02deadbeef01_746573742d61702d736165_managed_psk]
              Name=test-ap-sae
              SSID=746573742d61702d736165
              Passphrase=alittlelost
              Favorite=true
              AutoConnect=true
              IPv4.method=dhcp
              EOF
            '';
        };

        # === dnsmasq + static IPs for wlan0*

        # Setup networking + DHCP (dnsmasq) for the simulated wireless APs.
        # Without this connman will wait ages for a (non-existant) DHCP
        # offer, making the tests unbearably slow.
        networking.interfaces = {
            wlan0 = {
                ipv4.addresses = [{
                    address = "10.0.9.1"; # irrelevant
                    prefixLength = 24;
                }];
            };
            # Set known MAC address for client interface, needed in ConnMan service config
            wlan1 = {
                macAddress = "02:de:ad:be:ef:01";
            };
        };

        services.dnsmasq.enable = true;
        services.dnsmasq.settings = {
            interface = allSimulatedAPInterfaces;

            dhcp-option = [
                "3,10.0.9.2" # gateway, does not exist
                "6,10.0.9.3" # DNS, does not exist
            ];
            dhcp-range = "10.0.9.30,10.0.9.99,1h";
        };


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
            };
          };
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
playos.start()

with TestPrecondition("Test APs are setup and visible to connman"):
    playos.wait_for_unit("hostapd.service")
    playos.wait_for_unit("connman.service")
    playos.wait_for_unit("multi-user.target")

    # Wait until connman sees the AP.
    playos.wait_until_succeeds("connmanctl services | grep test-ap-sae", timeout=60)
    print(playos.succeed("connmanctl services wifi_02deadbeef01_746573742d61702d736165_managed_psk"))

with TestCase("connman applies retry mechanism after SAE auth failure") as t:
    # We connect with an incorrect passphrase, which is our hack to make the
    # added retry mechanism for failed connects in ConnMan observable. We
    # expect the connection fails in this case, but want to see that ConnMan
    # did not give up on first disconnect.
    wait_for_logs(
        playos,
        regex="can still retry favorite wifi in state 5 \\(5/5\\)",
        unit="connman.service",
        timeout=60
    )

    # We expect at least one auth attempt per retry allowed by ConnMan
    auth_attempts = int(playos.succeed('journalctl -u wpa_supplicant-wlan1 | grep "SME: Trying to authenticate with 02:00:00:00:00:00" | wc -l'))
    t.assertGreaterEqual(auth_attempts, 5)
  '';
}
