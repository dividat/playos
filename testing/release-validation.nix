# This is meant to be the final _automated_ validation test before
# pushing the release out for manual testing/QA.
#
# It tests the self-update scenario from an earlier release (the 'base' system)
# to the current/upcoming release (the 'next' system).
#
# It is "untainted" because it does not alter the configuration of the base or
# next systems' in any way (e.g. no test-instrumentation.nix extras). Instead it
# sets up a simulated environment (DHCP, DNS, update server, etc.) and runs the
# base system in it, interacting via "physical" inputs (mouse, keyboard using
# QEMU's QMP) and observing the results via screenshots+OCR.
#
# The test can be run non-interactively, but for debugging you will definitely
# need visible output since there are no logs. This can be done using:
#
#   nix-build -A driverInteractive testing/release-validation.nix
#   ./result/bin/nixos-test-driver
#   >> run_tests()
#
# The base system images have a passwordless root account, so
# you can gain root access from the QEMU GUI:
#   - switch to QEMU monitor console (using ctrl-alt-2 or the menu)
#   - execute "sendkey ctrl-shift-f8" (switch to status screen on TTY8)
#   - execute "sendkey ctrl-shift-f1" (switch to TTY1)
#   - login with "root"
let
    baseS3URL = "https://dividat-playos-test-disks.s3.amazonaws.com/by-tag";
    # Generated via ./build release-disk and .github/workflows/release-tag.yml
    # See https://github.com/dividat/playos/releases
    diskImageURLs = {
        "1.0.0-TEST" = {
            url = "${baseS3URL}/playos-disk-1.0.0-TEST.img.zst";
            hash = "sha256-7cyStGfsxVyQ2ugkI9XRFnNrnPhd5QRf+oAQxLu3ovM=";
        };
    };
in
{
    pkgs ? import ../pkgs { },

    application ? import ../application.nix,

    safeProductName ? application.safeProductName,

    # Note: the base system disk must be built with update and kiosk URLs which:
    # 1) have proper domain names (i.e. not localhost or plain IPs)
    # 2) do not use HTTPS
    updateUrlDomain ? "update-server.local",
    kioskUrlDomain ? "kiosk-server.local",

    # PlayOS system we are updating from
    baseSystemVersion ? "1.0.0-TEST",

    # A downloadable URL containing a zstd compressed disk image
    baseSystemDiskImage ? (pkgs.fetchurl diskImageURLs.${baseSystemVersion})
        .overrideAttrs {
            __structuredAttrs = true;
            unsafeDiscardReferences.out = true;
        },

    # PlayOS version we are updating into.
    # Only used in the stub update server, not set in the bundle, etc.
    nextSystemVersion ? "9999.99.99",

    # PlayOS bundle for the next update
    nextSystemBundlePath ? (pkgs.callPackage ../default.nix {
        updateUrl = "http://${updateUrlDomain}/";
        kioskUrl = "http://${kioskUrlDomain}/";
        # This override is not needed if application.version is "already" newer
        # than base
        versionOverride = nextSystemVersion;
    }).components.unsignedRaucBundle,
}:
let
    overlayPath = "/tmp/release-validation-disk.raw";
in
with pkgs.lib;
pkgs.testers.runNixOSTest {
  name = "Older releases of PlayOS self-update to newer";

  nodes = {
    # runs a DNS server and a mock HTTP update/bundle server
    sidekick = { config, nodes, lib, pkgs, ... }:
    {
      config = {
        networking.dhcpcd.enable = false;

        networking.primaryIPAddress = "192.168.1.${toString config.virtualisation.test.nodeNumber}";

        # disable QEMU `-net user` interface to have less moving parts
        virtualisation.qemu.networkingOptions = lib.mkOverride 0 [ ];

        # will not work, because playos receives IP settings via DHCP
        networking.extraHosts = lib.mkOverride 0 "";

        virtualisation.vlans = [ 1 ];
        networking.firewall.enable = false;

        services.static-web-server.enable = true;
        services.static-web-server.listen = "[::]:80";
        services.static-web-server.root = "/tmp/www";

        systemd.tmpfiles.rules = [
            "d ${config.services.static-web-server.root} 0777 root root -"
        ];

        services.dnsmasq.enable = true;
        services.dnsmasq.settings = {
            dhcp-option = [
                "3,${config.networking.primaryIPAddress}" # self as gateway
                "6,${config.networking.primaryIPAddress}" # self as DNS
            ];
            dhcp-range = "192.168.1.30,192.168.1.99,1h";
            address = [
                "/${updateUrlDomain}/${config.networking.primaryIPAddress}"
                "/${kioskUrlDomain}/${config.networking.primaryIPAddress}"
            ];
        };
      };
    };
    # Note: playos is started from pre-built disk _without_ any test
    # instrumentation, there's no test-driver "backdoor", no shared files, etc.
    # Therefore the only way to interact is via QMP.
    playos = { config, lib, pkgs, ... }:
    {
      imports = [
        (import ./end-to-end/virtualisation-config.nix { inherit overlayPath; })
      ];
      config = {
        # disable QEMU VNET
        virtualisation.qemu.networkingOptions = lib.mkOverride 0 [ ];
        virtualisation.sharedDirectories = lib.mkOverride 0 { };

        # Note: this has to be at least 2x bundle size, otherwise
        # the bundle download will not fit into /tmp (which is defined
        # as 50% of RAM)!
        virtualisation.memorySize = lib.mkForce 4096;

        virtualisation.vlans = [ 1 ];

        virtualisation.qemu.options = [
            # needed for mouse_move to work
            "-device" "usb-mouse,bus=usb-bus.0"
        ];
      };
    };
  };

  interactive.nodes.playos.virtualisation.qemu.options = [
    # extra QEMU monitor GUI access for debugging when running interactively
    "-monitor" "vc"
  ];

  enableOCR = true;

  extraPythonPackages = ps: [
    ps.colorama
    ps.types-colorama
    ps.requests
    ps.types-requests
    ps.tesserocr
  ];

  testScript = {nodes}: ''
${builtins.readFile ./helpers/nixos-test-script-helpers.py}
${builtins.readFile ./end-to-end/tests/base/proxy-and-update-helpers.py}
import tesserocr # type: ignore
import tempfile
import time
import atexit
import os

# Note #1: extracting the compressed disk in the test rather than in a
# derivation to avoid bloating nix store with a 10GB+ file
# Note #2: no need to create a COW overlay, since we can write to the temp disk
# image directly
def extract_base_system_disk(compressed_disk, target_path):
    eprint("Extracting compressed disk image, this will take a while...")
    subprocess.run(["rm", "-f", target_path])
    subprocess.run(['${pkgs.zstd}/bin/unzstd', compressed_disk, '-o', target_path],
        check=True)
    os.chmod(target_path, 0o666)
    atexit.register(os.remove, target_path)

product_name = "${safeProductName}"
next_version = "${nextSystemVersion}"

http_root = "${nodes.sidekick.services.static-web-server.root}"
http_local_url = "http://127.0.0.1"

extract_base_system_disk("${baseSystemDiskImage}", "${overlayPath}")
playos.start(allow_reboot=True)
sidekick.start()

# Less accurate, but much faster OCR than NixOS `get_screen_text`,
# which takes almost 20 seconds per call.
# Fails to identify white text on dark backgrounds.
def screenshot_and_ocr(vm):
    with tempfile.TemporaryDirectory() as d:
        vm.screenshot(d + "/screenshot.png")
        return tesserocr.file_to_text(d + "/screenshot.png")

def wait_until_passes(test, retries=10, sleep=1):
    while True:
        try:
            return test()
        except Exception as e:
            if retries > 0:
                time.sleep(sleep)
                retries -= 1
            else:
                raise e

### === Stub Update server setup

with TestPrecondition("Stub update server is started"):
    update_server = UpdateServer(sidekick, product_name, http_root)
    update_server.wait_for_unit()
    sidekick.succeed(f"echo 'Hello world!' > {http_root}/index.html")
    sidekick.succeed(f"curl -f {http_local_url}")

with TestPrecondition("Stub update server is functional") as t:
    update_server.add_bundle(next_version, filepath="${nextSystemBundlePath}")
    update_server.set_latest_version(next_version)
    out_v = sidekick.succeed(f"curl -f {http_local_url}/latest")
    t.assertEqual(out_v, next_version)

with TestPrecondition("dnsmasq hands out an IP to playos"):
    dhcp_seq = [
        "DHCPOFFER.*192.168.1.3",
        "DHCPREQUEST.*192.168.1.3",
        "DHCPACK.*192.168.1.3.*playos",
    ]
    for msg in dhcp_seq:
        wait_for_logs(sidekick, msg, unit="dnsmasq.service", timeout=60)

    playos_ip = sidekick.succeed("cat /var/lib/dnsmasq/dnsmasq.leases | grep playos | awk '{print $3}'").strip()

    sidekick.succeed(f"ping -c1 {playos_ip}", timeout=3)

with TestPrecondition("kiosk is open with kiosk URL") as t:
    wait_until_passes(
        lambda: t.assertIn("Hello world", screenshot_and_ocr(playos))
    )

# move mouse to bottom right corner so it doesn't accidentally cover
# any text while OCR'ing
playos.send_monitor_command("mouse_move 2000 2000")

with TestPrecondition("controller GUI is visible") as t:
    # switch to controller
    playos.send_key("ctrl-shift-f12")

    def t_check():
        screen_text = screenshot_and_ocr(playos)
        t.assertIn("Information", screen_text)
        return screen_text

    screen_text = wait_until_passes(t_check, retries=3)

    t.assertIn("Version", screen_text)
    t.assertIn("${baseSystemVersion}", screen_text)


# Navigate to system status page using keyboard only.
# Hack: depends on current UI layout. Could be made more
# sophisticated by using tesseract to detect the bounding box
# and then mouse_move'ing there for a click
def navigate_to_system_status():
    for _ in range(4):
        playos.send_key("tab")
    playos.send_key("ret")
    time.sleep(1)

with TestPrecondition("Navigate to System Status page") as t:
    navigate_to_system_status()
    screen_text = screenshot_and_ocr(playos)
    t.assertIn("Update State", screen_text,
        "Update State not visible in screen, navigation failed?")

with TestCase("controller starts downloading the bundle") as t:
    def t_check():
        playos.send_key("ctrl-r")
        time.sleep(2)
        navigate_to_system_status()
        screen_text = screenshot_and_ocr(playos)
        t.assertIn("Downloading", screen_text)

    wait_until_passes(t_check, retries=30, sleep=1)

with TestCase("controller has downloaded and installed the bundle") as t:
    def t_check():
        playos.send_key("ctrl-r")
        time.sleep(2)
        navigate_to_system_status()
        screen_text = screenshot_and_ocr(playos)
        print(f"Current sreen text: {screen_text}")
        # return early if there is an error
        possible_errors = ["ErrorDownloading", "ErrorInstalling", "UpdateError"]
        if any([e in screen_text for e in possible_errors]):
            return screen_text
        t.assertIn("RebootRequired", screen_text)

    # controller takes at least 2 minutes for the download
    # (1.2GB @ 10 MB/s), so allow up to 5 minutes for the download+install
    screen_text = wait_until_passes(t_check, retries=30, sleep=10)
    if screen_text is not None:
        t.fail(f"Update process failed with an error, last screen text: {screen_text}")


# Reboot to new system
playos.send_monitor_command("system_reset")

with TestCase("kiosk is open with kiosk URL after reboot") as t:
    wait_until_passes(
        lambda: t.assertIn("Hello world", screenshot_and_ocr(playos)),
        retries=60
    )

playos.send_monitor_command("mouse_move 2000 2000")

with TestCase("controller GUI with new version is visible") as t:
    # switch to controller
    playos.send_key("ctrl-shift-f12")
    wait_until_passes(
        lambda: t.assertIn("${nextSystemVersion}", screenshot_and_ocr(playos))
    )
'';
}
