let
  pkgs = import ../../pkgs { };

  # Boilerplate params for PlayOS controller
  version = "1.1.1-TEST";
  greeting = s: "hello: ${s}";
  updateUrl = "http://update-server.local/";
  kioskUrl = "http://127.0.0.1:3355";

  playos-controller = import ../../controller {
    inherit pkgs version updateUrl kioskUrl;
    bundleName = "playos-bundle";
  };
in
pkgs.testers.runNixOSTest {
  name = "Controller labeling network services";

  nodes = {
    senso = { config, pkgs, ... }: {
      services.avahi = {
        enable = true;
        nssmdns4 = true;

        publish = {
          enable = true;
          addresses = true;
          domain = true;
          userServices = true;
          workstation = true;
        };
      };

      environment.systemPackages = [ pkgs.avahi ];
    };

    playos_with_avahi = { config, ... }: {
      imports = [
        (import ../../base {
          inherit pkgs kioskUrl playos-controller greeting version;
          fullProductName = "playos_with_avahi";
          safeProductName = "playos_with_avahi";
        })
      ];

      config = {
        services.connman.enable = pkgs.lib.mkOverride 0 true; # disabled in runNixOSTest by default

        playos.controller.annotateDiscoveredServices = [ "_soundso._tcp" ];

        playos.storage = {
          persistentDataPartition = {
            device = "tmpfs";
            fsType = "tmpfs";
            options = [ "mode=0755" ];
          };
        };
      };
    };

    playos_no_avahi = { config, ... }: {
      imports = [
        (import ../../base {
          inherit pkgs kioskUrl playos-controller greeting version;
          fullProductName = "playos_no_avahi";
          safeProductName = "playos_no_avahi";
        })
      ];

      config = {
        services.connman.enable = pkgs.lib.mkOverride 0 true; # disabled in runNixOSTest by default

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

  testScript =
''
${builtins.readFile ../helpers/nixos-test-script-helpers.py}
start_all()

playos_with_avahi.wait_for_unit("playos-controller.service")
playos_with_avahi.wait_until_succeeds("curl --fail http://localhost:3333/")

with TestPrecondition("avahi browse finds Senso service"):
    # Publish our service of interest
    senso.succeed("avahi-publish -s 'Davidat Soundso' _soundso._tcp 8080 >&2 &")
    # Also publish a service with 'malicious' instance name
    senso.succeed("avahi-publish -s '<script>Inject</script>' _soundso._tcp 8080 >&2 &")

    # Ensure it is picked up
    playos_with_avahi.wait_until_succeeds("test `avahi-browse -r -t _soundso._tcp | wc -l` -gt 0")
    print(playos_with_avahi.succeed("avahi-browse -pfc _soundso._tcp"))

with TestCase("System without avahi can list networks"):
    playos_no_avahi.succeed("curl --fail http://localhost:3333/network | grep Wired")

with TestCase("Label is applied"):
    playos_with_avahi.wait_until_succeeds("curl http://localhost:3333/network | grep 'Davidat Soundso'")

with TestCase("Injectable label contents are escaped"):
    playos_with_avahi.wait_until_succeeds("curl http://localhost:3333/network | grep '&lt;script&gt;Inject&lt;/script&gt;'")
'';

}
