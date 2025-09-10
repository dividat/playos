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

        # Includes non-existent "bigfoot" in services of interest, to confirm it does not break anything
        playos.controller.annotateDiscoveredServices = [ "_soundso._tcp" "_yesyes._udp" "_bigfoot._tcp" ];

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
    # Publish our services of interest
    senso.succeed("avahi-publish --service 'Davidat Soundso' _soundso._tcp 8080 >&2 &")
    senso.succeed("avahi-publish --service 'Yes Man' _yesyes._udp 2233 >&2 &")
    # Also publish a service with 'malicious' instance name
    senso.succeed("avahi-publish --service '<script>Inject</script>' _soundso._tcp 8080 >&2 &")

with TestCase("System without avahi can list networks"):
    playos_no_avahi.succeed("curl --fail http://localhost:3333/network | grep Wired")

with TestCase("Label is applied"):
    playos_with_avahi.wait_until_succeeds("curl http://localhost:3333/network | grep 'Davidat Soundso'")
    playos_with_avahi.wait_until_succeeds("curl http://localhost:3333/network | grep 'Yes Man'")

with TestCase("Injectable label contents are escaped"):
    playos_with_avahi.wait_until_succeeds("curl http://localhost:3333/network | grep '&lt;script&gt;Inject&lt;/script&gt;'")
'';

}
