let
  pkgs = import ../../pkgs { };

  # url from where updates should be fetched
  updateUrl = "http://update-server.local/";

  # hard-coded in controller
  captivePortalUrl = "http://captive.dividat.com/";

  # irrelevant, but needed
  kioskUrl = "http://127.0.0.1:3355";

  fullProductName = "playos";
  safeProductName = "playos";
  version = "1.1.1-TEST";
  greeting = s: "hello: ${s}";


  playos-controller = import ../../controller {
    inherit pkgs version updateUrl kioskUrl;
    bundleName = safeProductName;
  };
in
pkgs.testers.runNixOSTest {
  name = "Controller uses proxy for captive portal and update fetching";

  nodes = {
    sidekick = { config, nodes, lib, pkgs, ... }: {
      config = {
        virtualisation.vlans = [ 1 ];
        networking.firewall.enable = false;

        services.static-web-server.enable = true;
        services.static-web-server.listen = "[::]:80";
        services.static-web-server.root = "/tmp/www";

        systemd.tmpfiles.rules = [
            "d ${config.services.static-web-server.root} 0777 root root -"
        ];

        # the proxy achieves two things:
        # - is used to test that proxy settings are honoured
        # - acts as a make-shift DNS for resolving domains to test VM IPs
        #   since there is no other convenient way to do this
        services.tinyproxy.enable = true;
        services.tinyproxy.settings = let
            update_host_port = builtins.head
                (builtins.match "https?://([^/]+)/?" updateUrl);
            captive_host_port = builtins.head
                (builtins.match "https?://([^/]+)/?" captivePortalUrl);
        in {
          Port = 8888;
          Listen = "0.0.0.0";
          Upstream = [
            ''http 127.0.0.1:80 "${update_host_port}"''
            ''http 127.0.0.1:80 "${captive_host_port}"''
          ];
          LogLevel = "Critical"; # comment out to debug proxied reqs
        };

        virtualisation.qemu.options = [
            "-enable-kvm"
        ];
      };
    };
    playos = { config, ... }: {
      imports = [
        (import ../../base {
          inherit pkgs kioskUrl playos-controller;
          inherit safeProductName fullProductName greeting version;
        })
        ../system/fake-rauc-boot.nix
      ];

      config = {
        networking.firewall.enable = false;

        services.connman = {
          enable = pkgs.lib.mkOverride 0 true; # disabled in runNixOSTest by default
        };

        playos.storage = {
          persistentDataPartition = {
            device = "tmpfs";
            fsType = "tmpfs";
            options = [ "mode=0755" ];
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

latest_version = "9.9.9-TEST"

http_root = "${nodes.sidekick.services.static-web-server.root}"
http_local_url = "http://127.0.0.1"

proxy_url = "http://sidekick:8888"

playos.start()
sidekick.start()

with TestPrecondition("Stub HTTP server is functional"):
    sidekick.succeed("echo 'TEST_CAPTIVE_RESPONSE' > /tmp/www/index.html")
    sidekick.succeed(f"echo '{latest_version}' > /tmp/www/latest")
    sidekick.succeed(f"curl --fail -v {http_local_url}")
    sidekick.succeed(f"curl --fail -v {http_local_url}/latest")

### === PlayOS setup

with TestPrecondition("PlayOS is booted, RAUC and controller are started"):
    playos.wait_for_unit('multi-user.target')
    playos.wait_for_unit('rauc.service')
    playos.wait_for_unit('playos-controller.service')

with TestPrecondition("PlayOS can manually use proxy in sidekick VM"):
    wait_until_passes(lambda: playos.succeed(f"curl -f --proxy {proxy_url} ${updateUrl}"),
                      retries=60) # on CI, sidekick is not reachable quite long
    playos.succeed(f"curl -f --proxy {proxy_url} ${captivePortalUrl}")

with TestPrecondition("Controller fails to reach captive portal without proxy"):
    # when running interactively network is not isolated, so without the grep
    # this would succeed
    playos.fail("curl -f http://localhost:3333/internet/status | grep TEST_CAPTIVE_RESPONSE") 

configure_proxy(playos, proxy_url)

### === Test scenario

with TestCase("Controller uses proxy for captive portal"):
   playos.succeed("curl -f http://localhost:3333/internet/status | grep TEST_CAPTIVE_RESPONSE") 

with TestCase("Controller is able to query the version and initiate download"):
    wait_for_logs(playos,
        f"Downloading.*{latest_version}",
        unit="playos-controller.service",
        timeout=61)
'';
}
