{pkgs, disk, overlayPath, kioskUrl, ...}:
let
    # TODO: set/get in application.nix
    guestCDPport = 3355;
    hostCDPport = 13355;
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
            {   from = "host";
                # TODO: would be nicer to get a random port instead
                host.port = hostCDPport;
                guest.port = guestCDPport;
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
import json
import requests
import pyppeteer # type: ignore
import asyncio

aio = asyncio.Runner()

create_overlay("${disk}", "${overlayPath}")

playos.start(allow_reboot=True)

with TestCase("PlayOS disk boots"):
    playos.wait_for_unit('multi-user.target')
    playos.wait_for_x()

with TestCase("PlayOS services are runnning"):
    playos.wait_for_unit('dividat-driver.service')
    playos.wait_for_unit('playos-controller.service')
    playos.wait_for_unit('playos-status.service')

async def connect_to_kiosk_debug_engine():
    # TODO: enable runtime configuration of the remote debugging URL instead
    expose_local_port(playos, ${toString guestCDPport})

    async def try_connect():
        # connect to Qt WebEngine's CDP debug port
        host_cdp_url = "http://127.0.0.1:${toString hostCDPport}/json/version"
        cdp_info = requests.get(host_cdp_url).json()
        ws_url = cdp_info['webSocketDebuggerUrl']
        browser = await pyppeteer.launcher.connect(browserWSEndpoint=ws_url)
        return browser

    # Sometimes I get connection reset by peer when connecting, I am guessing
    # due to firewall restart when doing `expose_local_port`? Hence the retry.
    return await retry_until_no_exception(try_connect)


# Helper used to check web storage persistance after a reload or
# a reboot ("hard" reload)
async def check_web_storages_after_reload(page, t, hard_reload=False):
    ss = await page.evaluate('sessionStorage.getItem("TEST_KEY")')
    ls = await page.evaluate('localStorage.getItem("TEST_KEY")')
    # Note: CDP automatically awaits the JS call
    cs = await page.evaluate('cookieStore.get("TEST_KEY")')

    # TODO: do we care about sessionStorage, actually?
    expected_ss_val = None if hard_reload else "TEST_VALUE"
    t.assertEqual(
        ss,
        expected_ss_val,
        "Session store did not contain expected TEST_KEY value:" + \
            f"(found {ss}, expected: {expected_ss_val})"
    )

    # localStorage and cookieStore should be persisted
    t.assertEqual(
        ls, "TEST_VALUE",
        "TEST_KEY was not persisted in localStorage"
    )
    t.assertIn("value", cs,
        "Cookie store did not return a value"
    )
    t.assertEqual(
        cs['value'], "TEST_VALUE",
        "TEST_KEY was not persisted in cookieStore"
    )


async def wait_for_kiosk_page(browser):
    pages = await browser.pages()
    t.assertEqual(
        len(pages), 1,
        f"Expected 1 browser page, found: {[page.url for page in pages]}"
    )

    page = pages[0]

    t.assertIn(
        "${kioskUrl}".rstrip("/"),
        page.url,
        "kiosk is not open with ${kioskUrl}"
    )
    return page

with TestCase("Kiosk is open, web storage works") as t:
    browser = aio.run(connect_to_kiosk_debug_engine())

    # The retry is here because it seems that Qt WebEngine is reloading
    # something after the firewall reload and it takes a while until
    # it actually loads the kiosk page.
    page = aio.run(retry_until_no_exception(
        lambda: wait_for_kiosk_page(browser),
        retries=5
    ))

    # store something in all the web storage engines
    async def populate_web_storages():
        await page.evaluate('sessionStorage.setItem("TEST_KEY", "TEST_VALUE")')
        await page.evaluate('localStorage.setItem("TEST_KEY", "TEST_VALUE")')
        await page.evaluate('cookieStore.set("TEST_KEY", "TEST_VALUE")')

    aio.run(populate_web_storages())

    aio.run(page.reload())

    # mostly a sanity check, real check after reboot
    aio.run(check_web_storages_after_reload(page, t))

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

# TODO: currently fails ??!
#with TestCase("kiosk's web storage is restored") as t:
#    browser = aio.run(connect_to_kiosk_debug_engine())
#    page = aio.run(retry_until_no_exception(lambda: wait_for_kiosk_page(browser)))
#    aio.run(check_web_storages_after_reload(page, t, hard_reload=True))
'';

}
