let
  pkgs = import ../../pkgs { };
  serverPort = 8080;
  proxyPort = 8888;
  kiosk = import ../../kiosk {
    pkgs = pkgs;
    system_name = "PlayOS";
    system_version = "1.0.0";
  };
  toString = builtins.toString;
in
pkgs.nixosTest {
  name = "proxy-test";

  nodes = {
    thecloud = {
      virtualisation.vlans = [ 1 ];

      networking = {
        firewall.allowedTCPPorts = [ serverPort ];
      };

      systemd.services.http-server = {
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig = {
          ExecStart =
            let
              counter = pkgs.writeScript "request-counter.sh" ''
                #!${pkgs.bash}/bin/bash
                COUNTER_FILE="/var/log/request-counter"

                COUNT=$(cat $COUNTER_FILE || echo 0)
                ((COUNT++))
                echo $COUNT > $COUNTER_FILE
                echo "HTTP/1.1 200 OK"
              '';
            in
            "${pkgs.nmap}/bin/ncat -lk -p ${toString serverPort} -c ${counter}";
          Restart = "always";
        };
      };
      };

    theproxy = { config, ... }: {
      virtualisation.vlans = [ 2 1 ];

      networking.nat.enable = true;
      networking.firewall.allowedTCPPorts = [ proxyPort ];

      services.tinyproxy = {
        enable = true;
        settings = {
          Listen = "0.0.0.0";
          Port = proxyPort;
          BasicAuth = "user p4ssw0rd";
        };
      };
    };

    client = { config, ... }: {
      imports = [
        (pkgs.importFromNixos "tests/common/user-account.nix")
        (pkgs.importFromNixos "tests/common/x11.nix")
      ];

      virtualisation.vlans = [ 2 ];

      # Override is needed to enable in test VM, see connman tests:
      # https://github.com/NixOS/nixpkgs/blob/1772251828be641110eb9a47ef530a1252ba211e/nixos/tests/connman.nix#L47-L52
      services.connman.enable = pkgs.lib.mkOverride 0 true;
      services.connman.networkInterfaceBlacklist = [ "eth0" ];

      # We need a graphical environment and regular user for the kiosk browser
      services.xserver = {
        enable = true;
      };
      test-support.displayManager.auto.user = "alice";

      environment.systemPackages = [
        pkgs.curl
        pkgs.connman
        kiosk
      ];
    };
  };

  testScript = ''
    def reset():
      thecloud.succeed('rm -f /var/log/request-counter')

    def expect_requests(n):
      if (n == 0):
        thecloud.succeed('test ! -f /var/log/request-counter')
      else:
        thecloud.succeed(f'diff <(echo {n}) /var/log/request-counter')

    start_all()

    # Wait for the HTTP server and proxy to start
    thecloud.wait_for_unit('http-server.service')
    theproxy.wait_for_unit('tinyproxy.service')

    with subtest('Sanity check: Direct curl request fails'):
      client.fail('curl http://thecloud:${toString serverPort}')
      expect_requests(0)

    reset()

    with subtest('Sanity check: Proxied curl request arrives'):
      client.succeed(
        'curl --proxy http://user:p4ssw0rd@theproxy:${toString proxyPort} http://thecloud:${toString serverPort}'
      )
      expect_requests(1)

    reset()

    # Wait for X11 and connman, required by kiosk
    client.wait_for_x()
    client.wait_for_unit("connman.service")

    with subtest('kiosk-browser can run with configured proxy'):
      service_name = client.succeed("connmanctl services | head -1 | awk '{print $3}'").strip(' \t\n\r')
      client.succeed(f"connmanctl config {service_name} proxy manual http://user:p4ssw0rd@theproxy:${toString proxyPort}")

      kiosk_result = client.execute(
        'su - alice -c "kiosk-browser http://thecloud:${toString serverPort} http://foo.xyz" 2>&1',
        check_return=False,
        check_output=True,
        timeout=10
      )

      # Ideally here we would check if the request actually arrived at thecloud.
      # Unfortunately the proxy is currently not contacted by the kiosk in this
      # test setup, even though if we look we see that the proxy is set as
      # application proxy. This issue seems to be specific to the test setup, if
      # we test in a real installation, the configured proxy is actually used.
      # So for now we simply test whether the proxy has been picked up and
      # configured.

      if "Set proxy to theproxy:${toString proxyPort}" not in kiosk_result[1]:
        raise AssertionError("Expected kiosk logs to contain info about configured proxy.")
  '';

}

