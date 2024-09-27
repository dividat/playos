{pkgs, disk, overlayPath, kioskUrl, ...}:
let
    # TODO: set/get in application.nix
    guestCDPport = 3355;
    hostCDPport = 13355;

    # TODO: assert that kioskUrl is actually http://IP:PORT
    kioskParts = builtins.match "http://(.*):([0-9]+).*" kioskUrl;
    guestKioskIP = builtins.elemAt kioskParts 0;
    guestKioskURLport = pkgs.lib.strings.toInt (builtins.elemAt kioskParts 1);
    hostKioskURLport = 18989;
in
pkgs.testers.runNixOSTest {
  name = "Built PlayOS is functional";

  nodes = {
    playos = { config, lib, pkgs, ... }:
    {
      imports = [
        (import ../virtualisation-config.nix { inherit overlayPath; })
      ];
      config = {
        virtualisation.forwardPorts = [
            # CDP access inside of PlayOS VM from test driver
            {   from = "host";
                host.port = hostCDPport;
                guest.port = guestCDPport;
            }

            # Forward kioskUrl from VM to build sandbox
            {   from = "guest";
                guest.address = guestKioskIP;
                guest.port = guestKioskURLport;
                host.address = "127.0.0.1";
                host.port = hostKioskURLport;
            }
        ];
      };

    };
  };

  extraPythonPackages = ps: [
    ps.types-colorama
    ps.pyppeteer
    ps.requests
    ps.types-requests
  ];

  testScript = ''
${builtins.readFile ../test-script-helpers.py}
${builtins.readFile ./playos-basic-helpers.py}
import json
import time
from enum import StrEnum, auto

class WebStorageBackends(StrEnum):
    LocalStorage = auto();
    Cookies = auto();

# Which Web Storage backends to test for persistence.
ENABLED_WEB_STORAGES = [
    WebStorageBackends.LocalStorage,
    # Cookies are disabled due to unreliable persistence timing
    # WebStorageBackends.Cookies,
]

create_overlay("${disk}", "${overlayPath}")

aio = asyncio.Runner()

run_stub_server(${toString hostKioskURLport})

playos.start(allow_reboot=True)

with TestCase("PlayOS disk boots"):
    playos.wait_for_unit('multi-user.target')
    playos.wait_for_x()

with TestCase("PlayOS services are runnning"):
    playos.wait_for_unit('dividat-driver.service')
    playos.wait_for_unit('playos-controller.service')
    playos.wait_for_unit('playos-status.service')

# Sanity-check: can reach stub server
playos.succeed("curl --fail '${kioskUrl}'")

async def wait_for_kiosk_page(browser):
    kiosk_url = "${toString kioskUrl}".rstrip("/")

    pages = await browser.pages()
    t.assertEqual(
        len(pages), 1,
        f"Expected 1 browser page, found: {[page.url for page in pages]}"
    )

    page = pages[0]

    t.assertIn(
        kiosk_url,
        page.url,
        f"kiosk is not open with {kiosk_url}"
    )
    return page

async def connect_and_get_kiosk_page():
    browser = await connect_to_kiosk_debug_engine(playos,
        guest_cdp_port = ${toString guestCDPport},
        host_cdp_port = ${toString hostCDPport}
    )
    page = await retry_until_no_exception(
        lambda: wait_for_kiosk_page(browser)
    )
    return page

# Helper to populate different web storage backends
async def populate_web_storages(page):
    if WebStorageBackends.LocalStorage in ENABLED_WEB_STORAGES:
        await page.evaluate(
            'localStorage.setItem("TEST_KEY", "TEST_VALUE")'
        )

    if WebStorageBackends.Cookies in ENABLED_WEB_STORAGES:
        # Using document.cookie since cookieStore is only available on HTTPS
        await page.evaluate(
            # max-age is needed to force persistence, otherwise it
            # will be treated as a session cookie and deleted on restart
            'document.cookie = "TEST_VALUE;max-age=3600"'
        )

# Helper used to check web storage persistance after a restart
async def check_web_storages_after_restart(page, t):
    if WebStorageBackends.LocalStorage in ENABLED_WEB_STORAGES:
        ls = await page.evaluate('localStorage.getItem("TEST_KEY")')
        # localStorage should be persisted
        t.assertEqual(
            "TEST_VALUE", ls,
            "TEST_KEY was not persisted in localStorage"
        )

    if WebStorageBackends.Cookies in ENABLED_WEB_STORAGES:
        cookie = await page.evaluate('document.cookie')
        # cookies should be persisted
        t.assertIn("TEST_VALUE", cookie,
            "TEST_VALUE cookie was not persisted"
        )

with TestCase("Kiosk is open, web storage is persisted") as t:
    page = aio.run(connect_and_get_kiosk_page())

    aio.run(populate_web_storages(page))

    if WebStorageBackends.Cookies in ENABLED_WEB_STORAGES:
        # the only "reliable" way to ensure cookies are flushed, see:
        # https://bugreports.qt.io/browse/QTBUG-52121
        sleep_duration = 31
        print(f"Sleeping {sleep_duration}s to ensure cookies are flushed to disk")
        time.sleep(sleep_duration)

    # check if data is persisted after kiosk is restarted
    playos.succeed("pkill -f kiosk-browser")

    new_page = aio.run(connect_and_get_kiosk_page())
    aio.run(check_web_storages_after_restart(new_page, t))

with TestCase("Booted from system.a") as t:
    rauc_status = json.loads(playos.succeed("rauc status --output-format=json"))
    t.assertEqual(
        rauc_status['booted'],
        "a"
    )

# mark other (b) slot as active and try to reboot into it
playos.succeed(
    'busctl call de.pengutronix.rauc / ' + \
        'de.pengutronix.rauc.Installer Mark ss "active" "other"'
)

# NOTE: 'systemctl reboot' fails because of some bug in test-driver
playos.shutdown()
playos.start()

playos.wait_for_x()

with TestCase("Booted into other slot") as t:
    rauc_status = json.loads(playos.succeed("rauc status --output-format=json"))
    t.assertEqual(
        rauc_status['booted'],
        "b",
        "Did not boot from other (i.e. system.b) slot"
    )

with TestCase("kiosk's web storage is restored") as t:
    page = aio.run(connect_and_get_kiosk_page())
    aio.run(check_web_storages_after_restart(page, t))
'';

}
