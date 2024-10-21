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
      };
    };
  };

  # Note: using mostly `wait_for_console_text` here, because test-driver
  # crashes if using `wait_for_unit` or other higher level asserts
  testScript = ''
    def wait_for_http():
        playos.wait_for_unit("playos-controller.service")
        # wait_for_open_port fails due to some test-driver error
        playos.wait_until_succeeds("curl --fail http://localhost:3333/")

    # without these the test-driver crashes in later asserts for unclear reasons
    def manual_restart():
        playos.reboot()
        # needed to avoid using wait_for_unit during reboot
        playos.wait_for_console_text("NixOS Stage 2")
        wait_for_http()


    playos.start(allow_reboot=True)
    wait_for_http()

    # ===== Reboot works
    with subtest("Reboot works"):
        playos.succeed("curl -X POST http://localhost:3333/system/reboot >&2")
        playos.wait_for_console_text("systemd.*The system will reboot now!")

    manual_restart()

    # ===== Factory reset works

    with subtest("Factory reset works"):
        # Ensure persistent-data-wipe service is loaded and exists
        playos.succeed("""
            systemctl show --no-pager \
                --property ActiveState \
                playos-wipe-persistent-data.service | grep 'ActiveState=inactive'
        """)
        playos.succeed("curl -X POST http://localhost:3333/system/factory-reset >&2")
        playos.wait_for_console_text("systemd.*Starting playos-wipe-persistent-data.service.")
        playos.wait_for_console_text("systemd.*The system will reboot now!")

    manual_restart()

    # ===== Switch slot works

    with subtest("Switch slot works"):
        playos.succeed("curl -X POST http://localhost:3333/system/switch/system.b >&2")
        playos.wait_for_console_text("rauc mark: activated slot system.b")
        playos.wait_for_console_text("systemd.*The system will reboot now!")

    manual_restart()

    # ===== Shutdown works
    with subtest("Shutdown works"):
        playos.succeed("curl -X POST http://localhost:3333/system/shutdown >&2")
        playos.wait_for_console_text("systemd.*System is powering down.")
        playos.crash() # avoids "Broken pipe" test failure
  '';

}
