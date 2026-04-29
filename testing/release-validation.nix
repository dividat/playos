# This is meant to be the final _automated_ validation test before
# pushing the release out for manual testing/QA.
#
# It tests the double-self-update scenario, updating PlayOS from a BASE system
# version to a PRE version and finally to the NEXT version.
#
# By default the system image in PRE and NEXT is the same and is the current
# PlayOS image. This setup tests whether the current system can self-update.
#
# The tested steps:
#    1. 'latest' is set to PRE in update server
#    2. BASE system downloads+installs PRE
#    3. VM reboots into PRE
#    4. PRE system is marked Good. First update (BASE->PRE) successful.
#    5. 'latest' is set to NEXT in update server
#    6. PRE downloads+installs NEXT
#    7. VM reboots into NEXT
#    8. NEXT system is marked Good. Second update (PRE->NEXT) successful.
#
# In theory, the PRE and NEXT bundles can be replaced with a different system
# image as long as they have the same build configuration (updateUrl and kioskUrl)
# and a passwordless root. This allows to test path-dependant update scenarios.
#
# The test is "untainted" because it does not alter the configuration of the
# base or next systems' in any way (e.g. no test-instrumentation.nix extras).
# Instead it sets up a simulated environment (DHCP, DNS, update server, etc.)
# and runs the base system in it, interacting via "physical" inputs (mouse,
# keyboard using QEMU's QMP) and observing the results via screenshots+OCR.
#
# The test can be run non-interactively, but for debugging you will definitely
# need visible output since there are no logs. This can be done using:
#
#   nix-build -A driverInteractive testing/release-validation.nix
#   ./result/bin/nixos-test-driver
#   >> run_tests()
#
# The system images have a passwordless root account, so you can gain root
# access from the QEMU GUI:
#   - switch to QEMU monitor console (using ctrl-alt-2 or the menu)
#   - execute "sendkey ctrl-alt-f8" (switch to status screen on TTY8)
#   - execute "sendkey ctrl-alt-f3" (switch to TTY3)
#   - login with "root"
let
    # Note: we use HTTP instead of HTTPS, because pkgs.fetchurl fails
    # when __structuredAttrs is enabled (due to mysterious OpenSSL/TLS errors)
    # and also fails when __structuredAttrs is disabled (due to
    # https://github.com/NixOS/nixpkgs/issues/177660).
    # HTTP usage is fine since the output hash is fixed and verifies the download.
    baseS3URL = "http://dividat-playos-test-disks.s3.amazonaws.com/by-tag";
    # Generated via ./build release-disk and .github/workflows/release-tag.yml
    # See https://github.com/dividat/playos/releases
    diskImageURLs = {
        "2020.7.0-DISK" = { # oldest PlayOS containing a "modern" GRUB config
            url = "${baseS3URL}/playos-release-disk-2020.7.0-DISK.img.zst";
            hash = "sha256-FRtbKScV3+hHYePLFiAJ62nuDaRUV+zWJMH9kukxScU=";
        };
        "2023.9.1-DISK" = {
            url = "${baseS3URL}/playos-release-disk-2023.9.1-DISK.img.zst";
            hash = "sha256-Az5eYYZFUweSzMSEBKIB6Q3mGtG0SLJ51LxWeeJqpfw=";
        };
        "2024.7.0-DISK" = { # fails double-update, needs backport+rebuild
            url = "${baseS3URL}/playos-release-disk-2024.7.0-DISK.img.zst";
            hash = "sha256-vJDB99ICt0W1PmONikNY5wwIF7oQU388DzYRgPqkooY=";
        };
        "2025.3.1" = {
            url = "${baseS3URL}/playos-release-disk-2025.3.1.img.zst";
            hash = "sha256-ySLOMGsDfeGU4r8xUOwW9M/VMKC8GpzhaKXVQwu5fxM=";
        };
        "2025.3.2" = { # fails double-update, needs backport+rebuild
            url = "${baseS3URL}/playos-release-disk-2025.3.2.img.zst";
            hash = "sha256-txgvrLtO2qq8JZlU/ijONnVLAMLK/6QyRutwej5UEWY=";
        };
        "2025.3.3" = {
            url = "${baseS3URL}/playos-release-disk-2025.3.3.img.zst";
            hash = "sha256-u71dsbtnzXrERQ20H1CmCj9K9S1t2aOG0elzcrLIsYY=";
        };
        "2026.1.0" = {
            url = "${baseS3URL}/playos-release-disk-2026.1.0.img.zst";
            hash = "sha256-M+fZJtoHONlPBIaWV0vjJCdvtwDH+a6TyoiV243/wfo=";
        };
        "2026.3.0" = {
            url = "${baseS3URL}/playos-release-disk-2026.3.0.img.zst";
            hash = "sha256-q8h4YRBRGzpm5ymGxardKVZTbq09x0wsoWWaejScQFo=";
        };
    };

    mkNextSystemBundle = { pkgs, version, updateUrlDomain, kioskUrlDomain }:
      (pkgs.callPackage ../default.nix {
          updateUrl = "http://${updateUrlDomain}/";
          kioskUrl = "http://${kioskUrlDomain}/";
          versionOverride = version;
      }).releaseValidation.components.unsignedRaucBundle;
in
{
    pkgs ? import ../pkgs { },

    application ? import ../application.nix,

    safeProductName ? application.safeProductName,

    # Note: the system images must all be built with the same update and kiosk URLs which:
    # 1) have proper domain names (i.e. not localhost or plain IPs)
    # 2) do not use HTTPS
    updateUrlDomain ? "update-server.local",
    kioskUrlDomain ? "kiosk-server.local",

    # PlayOS system we are updating from
    baseSystemVersion ? "2026.3.0",

    # A zstd-compressed PlayOS disk image
    baseSystemDiskImage ? (pkgs.fetchurl diskImageURLs.${baseSystemVersion})
        .overrideAttrs {
            __structuredAttrs = true;
            unsafeDiscardReferences.out = true;
        },

    # PlayOS versions we are updating into.
    #
    # There will be two updates: BASE -> PRE and PRE -> NEXT where PRE and NEXT
    # are by default the same (i.e. the current PlayOS system image).
    #
    # Note: these versions cannot be substrings of each other, since
    # we rely on (visually) detecting the values on screen.
    preSystemVersion ? "6666.66.66",
    nextSystemVersion ? "9999.99.99",

    # PlayOS bundles to be updated to
    preSystemBundlePath ? mkNextSystemBundle
      { version = preSystemVersion; inherit pkgs updateUrlDomain kioskUrlDomain; },
    nextSystemBundlePath ? mkNextSystemBundle
      { version = nextSystemVersion; inherit pkgs updateUrlDomain kioskUrlDomain; }
}:
let
    overlayPath = "/tmp/release-validation-disk.img";
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

        virtualisation.memorySize = lib.mkForce 4096;

        virtualisation.vlans = [ 1 ];
      };
    };
  };

  interactive.nodes.playos.virtualisation.qemu.options = [
    # extra QEMU monitor GUI access for debugging when running interactively
    "-monitor" "vc"
  ];

  extraPythonPackages = ps: [
    ps.playos-test-helpers
    ps.colorama
    ps.types-colorama
    ps.requests
    ps.types-requests
    ps.tesserocr
    ps.pillow
    ps.types-pillow
  ];

  testScript = {nodes}: ''
from playos_test_helpers import eprint, TestPrecondition, TestCheck, wait_for_logs, wait_until_passes
${builtins.readFile ./end-to-end/tests/base/proxy-and-update-helpers.py}
import atexit
import subprocess
import tempfile
import time
import tesserocr # type: ignore
import PIL.Image
import PIL.ImageEnhance
import PIL.ImageOps
import os
import contextlib

### Constants

product_name = "${safeProductName}"
pre_version = "${preSystemVersion}"
next_version = "${nextSystemVersion}"

http_root = "${nodes.sidekick.services.static-web-server.root}"
http_local_url = "http://127.0.0.1"

### Test helpers

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

@contextlib.contextmanager
def temp_screenshot(vm):
    # using temp file instead of dir leads to strange permission errors
    with tempfile.TemporaryDirectory() as d:
        temp_path = d + "/screenshot.png"
        vm.screenshot(temp_path)
        yield temp_path


# Faster OCR than NixOS `get_screen_text`, which takes almost 20 seconds per
# call. Fails to identify white text on dark backgrounds.
def screenshot_and_ocr(vm):
    with temp_screenshot(vm) as p:
      im = PIL.Image.open(p)
      im = PIL.ImageOps.grayscale(im)
      im = PIL.ImageEnhance.Brightness(im).enhance(1.5)
      im = PIL.ImageEnhance.Contrast(im).enhance(4.0)
      return tesserocr.image_to_text(im)


def find_text_locations(image_path: str, target_text: str):
    """
    Run OCR on the provider image and finds all instances of `target_text`
    inside it. Casing is ignored, all whitespace is collapsed to
    single spaces.

    Returns an iterator of center points of the bounding boxes containing the
    text.

    The returned (x, y) coordinates are NORMALIZED to [0, 1]x[0, 1]. This is
    meant to simplify usage with `mouse_click_in_location`. To convert back to
    pixels, multiply by the image dimensions.
    """
    level = tesserocr.RIL.TEXTLINE # OCR whole lines, not words

    # normalize to lowercase
    target_text = target_text.lower()

    with PIL.Image.open(image_path) as img, tesserocr.PyTessBaseAPI() as api:
        dim_x, dim_y = img.size
        api.SetImage(img)
        # Note: could also apply OCR-aiding enhancements like in
        # screenshot_and_ocr, but currently works well out of the box.
        api.Recognize()

        for element in tesserocr.iterate_level(api.GetIterator(), level):
            ocr_text = element.GetUTF8Text(level)
            ocr_text_clean = r" ".join(ocr_text.lower().split())

            # note: we assume at most 1 instance of target_text per line
            start_idx = ocr_text_clean.find(target_text)

            # find() returns -1 if no matches
            if start_idx >= 0:
                left, top, right, bottom = element.BoundingBox(level)

                # roughly estimate the position of the target_text within the
                # OCR'ed line based on char offsets
                center_char_idx = start_idx + (len(target_text) / 2.0)
                target_text_offset_frac = center_char_idx / len(ocr_text_clean)

                bbox_width = right - left
                center_x = left + (bbox_width * target_text_offset_frac)

                center_y = (top + bottom) / 2.0

                # Normalize coordinates to [0...1]
                normalized_x = center_x / dim_x
                normalized_y = center_y / dim_y
                yield (normalized_x, normalized_y)

    return None


# Note: using the QMP input-send-event command rather than `mouse_move`, because
# the latter does not work consistently with any of the mouse devices supported
# by QEMU.
def mouse_move_abs(vm, x: float, y: float):
    """
    Move the mouse pointer to the absolute point defined by normalized
    [0, 1]x[0, 1] coordinates (as returned by `find_text_locations()`).

    """
    # see https://qemu-project.gitlab.io/qemu/interop/qemu-qmp-ref.html#object-QMP-ui.InputMoveEvent
    qemu_max_coordinate = 0x7fff

    x_qemu = int(round(x * qemu_max_coordinate))
    y_qemu = int(round(y * qemu_max_coordinate))

    events = [
      { "type": "abs", "data" : { "axis": "x", "value" : x_qemu } },
      { "type": "abs", "data" : { "axis": "y", "value" : y_qemu } }
    ]

    vm.qmp_client.send("input-send-event", args = { "events": events })


def mouse_click_in_location(vm, x: float, y: float):
    """
    Move mouse to the specified absolute location (in normalized [0, 1]x[0, 1]
    coordinates) and perform a left-click.
    """
    mouse_move_abs(vm, x, y)
    time.sleep(0.3)
    # left-click
    vm.send_monitor_command("mouse_button 1")
    vm.send_monitor_command("mouse_button 0")
    time.sleep(0.3)

def move_mouse_to_corner():
  mouse_move_abs(playos, 1, 1)


def navigate_to_system_status():
    with temp_screenshot(playos) as path:
        locs = find_text_locations(path, "system status")
        if locs is None:
            raise RuntimeError("Failed to locate 'system status' link in page")

        # we might detect multiple locations (e.g. header of page + link)
        # click all of them hoping that we hit the right one
        for pos_x, pos_y in locs:
            mouse_click_in_location(playos, pos_x, pos_y)

    # move mouse away to not obstruct further OCR
    move_mouse_to_corner()
    time.sleep(2)


def check_for_text_in_status_page(text, ignore_errors=False):
    playos.send_key("ctrl-r")
    time.sleep(2)
    navigate_to_system_status()
    screen_text = screenshot_and_ocr(playos)
    print(f"Current sreen text: {screen_text}")

    # return early if there is an error
    if not ignore_errors:
        possible_errors = ["ErrorDownloading", "ErrorInstalling", "UpdateError"]
        if any([e in screen_text for e in possible_errors]):
            return screen_text

    t.assertIn(text, screen_text)

# Note: done via root shell on tty, since a QEMU system_reset corrupts the
# /boot/status.ini due to unclean unmount + FAT
def reboot_via_tty():
    playos.send_key("ctrl-alt-f8", delay=2) # direct switch to tty prevented by limit-vtes.nix
    playos.send_key("ctrl-alt-f3", delay=2)
    playos.send_chars("root\n")
    time.sleep(2)
    playos.send_chars("systemctl reboot\n")


### === Start VMs

extract_base_system_disk("${baseSystemDiskImage}", "${overlayPath}")
playos.start(allow_reboot=True)
sidekick.start()

### === Stub Update server setup

with TestPrecondition("Stub update server is started"):
    update_server = UpdateServer(sidekick, product_name, http_root)
    update_server.wait_for_unit()
    sidekick.succeed(f"echo 'Hello world!' > {http_root}/index.html")
    sidekick.succeed(f"curl -f {http_local_url}")

with TestPrecondition("Stub update server is functional") as t:
    update_server.add_bundle(pre_version, filepath="${preSystemBundlePath}")
    update_server.add_bundle(next_version, filepath="${nextSystemBundlePath}")
    update_server.set_latest_version(pre_version)
    out_v = sidekick.succeed(f"curl -f {http_local_url}/latest")
    t.assertEqual(out_v, pre_version)

### === Validate that PlayOS VM and baseSystem is OK

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
        lambda: t.assertIn("Hello world", screenshot_and_ocr(playos)),
        retries=60, # can take quite long on CI
        sleep=2
    )


# move mouse to bottom right corner so it doesn't accidentally cover
# any text while OCR'ing
move_mouse_to_corner()

with TestPrecondition("controller GUI is visible") as t:
    # switch to controller
    playos.send_key("ctrl-shift-f12")

    def t_check():
        screen_text = screenshot_and_ocr(playos)
        t.assertIn("Information", screen_text)
        time.sleep(2) # ensure page fully loaded
        return screen_text

    screen_text = wait_until_passes(t_check, retries=10)

    t.assertIn("Version", screen_text)
    t.assertIn("${baseSystemVersion}", screen_text)


with TestPrecondition("Navigate to System Status page") as t:
    navigate_to_system_status()
    screen_text = screenshot_and_ocr(playos)
    t.assertIn("Update State", screen_text,
        "Update State not visible in screen, navigation failed?")

### Helpers re-used in both BASE->PRE and PRE->NEXT

def check_update_is_downloaded_and_installed(stage):
  with TestCheck(f"{stage}: controller starts downloading the bundle") as t:
      def t_check():
          playos.send_key("ctrl-r")
          time.sleep(2)
          navigate_to_system_status()
          screen_text = screenshot_and_ocr(playos)
          t.assertIn("Downloading", screen_text)

      wait_until_passes(t_check, retries=30, sleep=1)

  with TestCheck(f"{stage}: controller has downloaded and installed the bundle") as t:
      # controller takes at least 2 minutes for the download
      # (1.2GB @ 10 MB/s), so allow up to 5 minutes for the download+install
      screen_text = wait_until_passes(
          lambda: check_for_text_in_status_page("RebootRequired"),
          retries=30, sleep=10)
      if screen_text is not None:
          t.fail(f"Update process failed with an error, last screen text: {screen_text}")


def check_system_boots_into_new_version(new_version, stage):
    with TestCheck(f"{stage}: kiosk is open with kiosk URL after reboot") as t:
        wait_until_passes(
            lambda: t.assertIn("Hello world", screenshot_and_ocr(playos)),
            retries=60,
            sleep=2
        )

    move_mouse_to_corner()

    with TestCheck(f"{stage}: controller GUI with new version is visible") as t:
        # switch to controller
        playos.send_key("ctrl-shift-f12")
        wait_until_passes(
            lambda: t.assertIn(new_version, screenshot_and_ocr(playos)),
            retries=10
        )

    with TestCheck(f"{stage}: The new booted version reaches a Good state") as t:
        wait_until_passes(
            # UpdateError possible initially, because DHCP has not completed
            lambda: check_for_text_in_status_page("Good", ignore_errors=True),
            retries=10, sleep=10)


print("======== First update (BASE->PRE) tests ========")

check_update_is_downloaded_and_installed("BASE->PRE")

reboot_via_tty()
# Note: we must immediatelly change the latest version to NEXT, because if
# controller determines it is UpToDate after the reboot, it will not do another
# check for an hour
update_server.set_latest_version(next_version)

check_system_boots_into_new_version(pre_version, "BASE->PRE")

print("======== First update (BASE->PRE) successful =============")

print("======== Start second (PRE->NEXT) update =================")

check_update_is_downloaded_and_installed("PRE->NEXT")

reboot_via_tty()

check_system_boots_into_new_version(next_version, "PRE->NEXT")

with TestCheck("Update state is UpToDate") as t:
    wait_until_passes(
        lambda: check_for_text_in_status_page("UpToDate", ignore_errors=True),
        retries=3, sleep=10)
'';
}
