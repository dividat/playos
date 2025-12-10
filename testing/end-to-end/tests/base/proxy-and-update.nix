{
    pkgs, qemu, disk, overlayPath, safeProductName, updateUrl,
    version,
    legacyMode ? false, # disable ext4 compatibility configuration, this mode is
                        # enabled in proxy-and-update-legacy.nix
    ...
}:
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

    versionsRequiringCompatScript = [
        "1.0.0" # a second version just to check array / looping works

        (if legacyMode then
            version # mark our own version as legacy
        else
            "1.0.1") # 1.0.1 is non-existant
    ];
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
    ${builtins.readFile ../../../helpers/nixos-test-script-helpers.py}
    ${builtins.readFile ./proxy-and-update-helpers.py}
    import json

    product_name = "${safeProductName}"
    current_version = "1.1.1-TESTMAGIC"

    http_root = "${nodes.sidekick.services.static-web-server.root}"
    http_local_url = "http://127.0.0.1"

    proxy_url = "http://${nodes.sidekick.networking.primaryIPAddress}:8888"

    is_legacy_mode = bool(${toString legacyMode}) # `toString false` returns ""
    bad_ext4_option = "metadata_csum_seed"

    create_overlay("${disk}", "${overlayPath}")
    playos.start(allow_reboot=True)
    sidekick.start()

    with TestCase("Installer produced a disk without incompatible FS features") as t:
        playos.wait_for_unit("local-fs.target")
        features = playos.succeed('tune2fs -l "/dev/disk/by-label/system.a" | grep "Filesystem features"')
        for bad_opt in ["metadata_csum_seed", "orphan_file"]:
            t.assertNotIn(bad_opt, features, f"ext4 was formatted with {bad_opt} by install-playos")

    if is_legacy_mode:
        with TestPrecondition("Setup legacy mode"):
            # enable all disabled features
            playos.succeed("cat /etc/mke2fs.conf | tr -d '^' > /tmp/mke2fs.conf")
            playos.succeed("mount --bind /tmp/mke2fs.conf /etc/mke2fs.conf")
            # RAUC does not see the bind mount unless restarted
            playos.wait_for_unit("rauc.service")
            playos.systemctl("restart rauc.service")

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

    configure_proxy(playos, proxy_url)

    ### === Test scenario

    with TestCase("Kiosk picks up the proxy"):
        proxy_host_port = proxy_url.replace("http://", "")
        expected_kiosk_logs = f"Set proxy to {proxy_host_port} in Qt application"
        wait_for_logs(playos, expected_kiosk_logs)

    with TestCase("Controller is able to query the version"):
        expected_states = [
            "GettingVersionInfo",
            "UpToDate",
            f"latest.*{current_version}"
        ]

        for state in expected_states:
            wait_for_logs(playos,
                state,
                unit="playos-controller.service",
                timeout=61)

    with TestCase("Controller installs the new upstream version") as t:
        next_version = "${nextVersion}"

        update_server.add_bundle(next_version, filepath="${nextVersionBundle}")
        update_server.set_latest_version(next_version)

        # reboot controller to trigger version check
        # TODO: override config to reduce check interval instead
        playos.systemctl("restart playos-controller.service")

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

    with TestCase("No raucb files left post-install") as t:
        playos.fail("ls /tmp/*.raucb")

    target_disk = "/dev/disk/by-label/system.b"

    with TestCase("RAUC post-install hook ran and performed compatibility fixes") as t:
        wait_for_logs(playos, "Checking if host system version requires compatibility fixes", unit="rauc.service")
        wait_for_logs(playos, "Detected host system version as ${version}", unit="rauc.service")

        if is_legacy_mode:
            wait_for_logs(playos, f"Removing {bad_ext4_option} from {target_disk}", unit="rauc.service")
            wait_for_logs(playos, f"Re-mounting {target_disk}", unit="rauc.service")
        else:
            wait_for_logs(playos, "Host system does not require compatibility fixes", unit="rauc.service")


    with TestCase("RAUC install produced a compatible filesystem") as t:
        features = playos.succeed(
            f'tune2fs -l "{target_disk}" | grep "Filesystem features"')
        t.assertNotIn(bad_ext4_option, features,
                      f"ext4 was formatted with {bad_ext4_option}")


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
