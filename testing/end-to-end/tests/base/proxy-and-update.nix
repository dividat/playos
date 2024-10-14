{pkgs, qemu, disk, overlayPath, safeProductName, updateUrl, ...}:
let
   nixos = pkgs.importFromNixos "";

   playosRoot = ./../../../..;

   nextVersion = "9999.99.99-TESTMAGIC";

   minimalTestSystem = (nixos {
      configuration = {modulesPath, ...}: {
        imports = [
            (modulesPath + "/profiles/qemu-guest.nix")
            (modulesPath + "/testing/test-instrumentation.nix")
            (modulesPath + "/profiles/minimal.nix")
            (playosRoot +  "/base/system-partition.nix")
            (playosRoot + "/base/volatile-root.nix")
        ];
        config = {
            system.nixos.label = "${safeProductName}-${nextVersion}";
            # just for test assertions
            environment.etc."PLAYOS_VERSION" = {
              text = nextVersion;
            };

            fileSystems = {
              "/boot" = {
                device = "/dev/disk/by-label/ESP";
              };
            };
            playos.storage = {
              systemPartition = {
                enable = true;
                device = "/dev/root";
                options = [ "rw" ];
              };
              persistentDataPartition = {
                device = "tmpfs";
                fsType = "tmpfs";
                options = [ "mode=0755" ];
              };
            };
            boot.loader.grub.enable = false;
        };
   };
   }).config.system.build.toplevel;

   nextVersionBundle = pkgs.callPackage (playosRoot + "/rauc-bundle/default.nix") {
    version  = nextVersion;
    systemImage = minimalTestSystem;
   };
in
pkgs.testers.runNixOSTest {
  name = "PlayOS can self-update, proxy settings work";

  nodes = {
    playos = { config, lib, pkgs, ... }:
    {
      imports = [
        (import ../../virtualisation-config.nix { inherit overlayPath; })
      ];
      virtualisation.vlans = [ 1 ];
    };
    # runs an HTTP proxy and a mock HTTP update/bundle server
    sidekick = { config, nodes, lib, pkgs, ... }:
    {
      config = {
        assertions = [ {
          assertion = !(lib.strings.hasInfix "localhost" updateUrl) &&
                      !(lib.strings.hasInfix "127.0.0.1" updateUrl);
          message = ''
              updateUrl cannot be localhost in these tests, because applications
              might by-pass proxy when connecting to loopback.
          '';
        } ];
        virtualisation.vlans = [ 1 ];
        networking.firewall.enable = false;

        services.static-web-server.enable = true;
        services.static-web-server.listen = "[::]:80";
        services.static-web-server.root = "/tmp/bundle-store";

        # the proxy achieves two things:
        # - is used to test that proxy settings are honoured
        # - acts as a make-shift DNS for resolving domains to test VM IPs
        #   since there is no other convenient way to do this
        services.tinyproxy.enable = true;
        services.tinyproxy.settings = let
            update_host_port = builtins.head
                (builtins.match "https?://([^/]+)/?" updateUrl);
        in {
          Port = 8888;
          Listen = "0.0.0.0";
          Upstream = ''http 127.0.0.1:80 "${update_host_port}"'';
          LogLevel = "Critical"; # comment out to debug proxied reqs
        };

        systemd.tmpfiles.rules = [
            "d ${config.services.static-web-server.root} 0777 root root -"
        ];

        virtualisation.qemu.options = [
            "-enable-kvm"
        ];
      };
    };
  };

  extraPythonPackages = ps: [
    ps.colorama
    ps.types-colorama
  ];


  testScript = {nodes}:
  ''
    ${builtins.readFile ../../test-script-helpers.py}
    ${builtins.readFile ./proxy-and-update-helpers.py}
    import json
    import re

    product_name = "${safeProductName}"
    current_version = "1.1.1-TESTMAGIC"

    http_root = "${nodes.sidekick.services.static-web-server.root}"
    http_local_url = "http://127.0.0.1"

    proxy_url = "http://${nodes.sidekick.networking.primaryIPAddress}:8888"

    create_overlay("${disk}", "${overlayPath}")
    playos.start(allow_reboot=True)
    sidekick.start()


    ### === Stub Update server setup

    with TestPrecondition("Stub update server is started"):
        update_server = UpdateServer(sidekick, product_name, http_root)
        update_server.wait_for_unit()
        sidekick.succeed(f"curl -v {http_local_url}")

    with TestPrecondition("Stub update server is functional") as t:
        update_server.add_bundle(current_version)
        update_server.set_latest_version(current_version)
        out_v = sidekick.succeed(f"curl -f {http_local_url}/latest")
        t.assertEqual(out_v, current_version)

    ### === PlayOS setup

    with TestPrecondition("PlayOS is booted, controller is started"):
        playos.wait_for_unit('multi-user.target')
        playos.wait_for_unit('playos-controller.service')

    # Not the most elegant setup, but works for now
    with TestPrecondition("Routing setup, check if sidekick VM is reachable") as t:
        # ens7 is the VLAN #1 interface
        playos.succeed("ip addr flush dev ens7")
        playos.succeed("ip addr add ${nodes.playos.networking.primaryIPAddress}/32 dev ens7")
        # 192.168.n.0 == VLAN #n
        playos.succeed("ip route add 192.168.1.0/24 dev ens7")

        # check if routing works
        playos.succeed("curl -f -L -v http://${nodes.sidekick.networking.primaryIPAddress}/latest")

        # check if proxy works
        playos.succeed(f"curl --proxy {proxy_url} -f -L -v http://update-server.local/latest")

    with TestPrecondition("Set HTTP proxy settings via connman") as t:
        # the output will also contain service types, filtered out below
        services = playos.succeed("connmanctl services").strip().split()
        default_service = None
        for s in services:
            if re.match("ethernet_.*_cable", s):
                info = playos.succeed(f"connmanctl services {s}")
                # default IP assigned to Guest VMs started with `-net user`
                if "Address=10.0.2.15" in info:
                    default_service = s
                    break

        if default_service is None:
            t.fail("Unable to find default interface among connman services")

        playos.succeed(f"connmanctl config {default_service} --proxy manual {proxy_url}")


    ### === Test scenario

    with TestCase("Kiosk picks up the proxy"):
        proxy_host_port = proxy_url.replace("http://", "")
        expected_kiosk_logs = f"Set proxy to {proxy_host_port} in Qt application"
        wait_for_logs(playos, expected_kiosk_logs)

    with TestCase("Controller is able to query the version"):
        expected_controller_log = f"latest.*{current_version}"
        wait_for_logs(playos,
            expected_controller_log,
            unit="playos-controller.service",
            # this should not be longer than 30, could there be some
            # DNS cache somehwere?
            timeout=61)

    with TestCase("Controller installs the new upstream version") as t:
        next_version = "${nextVersion}"

        sidekick.copy_from_host(
            "${nextVersionBundle}",
            "/tmp/next-bundle.raucb"
        )
        update_server.add_bundle(next_version, filepath="/tmp/next-bundle.raucb")
        update_server.set_latest_version(next_version)

        expected_states = [
            "Downloading",
            f"Installing.*{update_server.bundle_filename(next_version)}",
            "RebootRequired"
        ]

        for state in expected_states:
            wait_for_logs(playos,
                state,
                unit="playos-controller.service",
                # curl is limited to 10MB/s in controller, so
                # a 600 MB bundle will take at least 60s
                timeout=75)

    with TestCase("RAUC status confirms the installation") as t:
        rauc_status = json.loads(playos.succeed(
            "rauc status --detailed --output-format=json"
        ))
        t.assertEqual(
            rauc_status['boot_primary'],
            "system.b",
            "RAUC installation did not change boot primary other (i.e. system.b) slot"
        )

        b_slot = [s for s in rauc_status['slots'] if "system.b" in s][0]['system.b']
        slot_bundle_version = b_slot['slot_status']['bundle']['version']
        t.assertEqual(
            slot_bundle_version,
            next_version,
            "Installed bundle does not have correct version"
        )

    with TestCase("System boots into the new bundle") as t:
        playos.shutdown()
        playos.start()
        playos.wait_for_unit('multi-user.target')
        out_version = playos.succeed("cat /etc/PLAYOS_VERSION").strip()
        t.assertEqual(
            out_version,
            next_version,
            "Did not boot into the installed bundle?"
        )
  '';
}
