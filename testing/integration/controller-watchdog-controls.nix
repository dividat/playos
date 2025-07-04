let
  pkgs = import ../../pkgs { };


  # not used
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
pkgs.testers.runNixOSTest {
  name = "Controller system calls";

  nodes = {
    playos = { config, ... }: {
      imports = [
        (import ../../base {
          inherit pkgs kioskUrl playos-controller;
          inherit safeProductName fullProductName greeting version;
        })
        ../system/fake-rauc-boot.nix
      ];

      config = {
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
        playos.networking.watchdog = {
            enable = true;
            checkURLs = [ kioskUrl ];
        };

        users.users.play = {
          isNormalUser = true;
          home = "/home/play";
        };
      };
    };
  };

  testScript = ''

    playos.start()

    playos.wait_for_unit("playos-controller.service")
    playos.wait_until_succeeds("curl --fail http://localhost:3333/")
    playos.wait_for_unit("playos-network-watchdog.service")

    playos.succeed("systemctl is-active playos-network-watchdog.service")

    with subtest("Network watchdog disable works"):
        playos.succeed("curl -X POST http://localhost:3333/watchdog/disable")
        playos.wait_for_console_text("playos-network-watchdog.service: Deactivated successfully.")
        playos.fail("systemctl is-active playos-network-watchdog.service")
        playos.execute("systemctl restart playos-network-watchdog.service")
        playos.wait_for_console_text("watchdog was skipped because of an unmet condition")
        playos.fail("systemctl is-active playos-network-watchdog.service")

    with subtest("Network watchdog enable works"):
        playos.succeed("curl -X POST http://localhost:3333/watchdog/enable")
        playos.wait_for_unit("playos-network-watchdog.service")
        playos.succeed("systemctl is-active playos-network-watchdog.service")
        # restarting works, disable file has been removed
        playos.succeed("systemctl restart playos-network-watchdog.service")
        playos.succeed("systemctl is-active playos-network-watchdog.service")
  '';

}
