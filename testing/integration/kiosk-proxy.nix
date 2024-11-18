let
  pkgs = import ../../pkgs { };
  serverPort = 8080;
  proxyPort = 8888;
  kioskUrl = "http://kiosk.local/";
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
    theproxy = {
      virtualisation.vlans = [ 1 ];

      networking.firewall = {
        enable = false;
        allowedTCPPorts = [ proxyPort ];
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

      services.tinyproxy = {
        enable = true;
        settings = {
          Listen = "0.0.0.0";
          Port = proxyPort;
          BasicAuth = "user p4ssw0rd";
          Upstream = [
            ''http 127.0.0.1:8080 "${builtins.head (builtins.match "https?://([^/]+)/?" kioskUrl)}"''
          ];
        };
      };
    };

    client = { config, ... }: {
      imports = [
        (pkgs.importFromNixos "tests/common/user-account.nix")
        (pkgs.importFromNixos "tests/common/x11.nix")
      ];

      virtualisation.vlans = [ 1 ];

      # Override is needed to enable in test VM, see connman tests:
      # https://github.com/NixOS/nixpkgs/blob/1772251828be641110eb9a47ef530a1252ba211e/nixos/tests/connman.nix#L47-L52
      services.connman.enable = pkgs.lib.mkOverride 0 true;

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

  extraPythonPackages = ps: [
    ps.colorama
    ps.types-colorama
  ];


  testScript = ''
    ${builtins.readFile ../helpers/nixos-test-script-helpers.py}

    def reset():
      theproxy.succeed('rm -f /var/log/request-counter')

    def expect_requests(n = None):
      if n is None:
        theproxy.succeed('test -f /var/log/request-counter')
      elif n == 0:
        theproxy.succeed('test ! -f /var/log/request-counter')
      else:
        theproxy.succeed(f'diff <(echo {n}) /var/log/request-counter')

    start_all()

    # Wait for the HTTP server and proxy to start
    theproxy.wait_for_unit('http-server.service')
    theproxy.wait_for_unit('tinyproxy.service')

    with TestPrecondition('Direct curl request to kiosk URL fails'):
      client.fail('curl ${kioskUrl}')
      expect_requests(0)

    reset()

    with TestPrecondition('Proxied curl request to kiosk URL arrives'):
      client.succeed(
        'curl --proxy http://user:p4ssw0rd@theproxy:${toString proxyPort} ${kioskUrl}/test'
      )
      expect_requests(1)

    reset()

    # Wait for X11 and connman, required by kiosk
    client.wait_for_x()
    client.wait_for_unit("connman.service")

    with TestCase('kiosk-browser uses configured proxy'):
      service_name = client.succeed("connmanctl services | head -1 | awk '{print $3}'").strip(' \t\n\r')
      client.succeed(f"connmanctl config {service_name} proxy manual http://user:p4ssw0rd@theproxy:${toString proxyPort}")

      kiosk_result = client.execute(
        'su - alice -c "kiosk-browser ${kioskUrl} http://foo.xyz" 2>&1',
        check_return=False,
        check_output=True,
        timeout=10
      )

      # Expect proxy takeup in kiosk logs
      if "Set proxy to theproxy:${toString proxyPort}" not in kiosk_result[1]:
        print(kiosk_result[1])
        raise AssertionError("Expected kiosk logs to contain info about configured proxy.")

      # Expect kiosk request in proxy logs
      wait_for_logs(theproxy, "GET http://kiosk.local/ HTTP", unit="tinyproxy.service")

      # Expect arrival of one or more requests at the mock server
      expect_requests()
'';

}

