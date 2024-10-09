import http.server
import multiprocessing as mp
import requests
import asyncio
import pyppeteer # type: ignore

# Forward external `port` to 127.0.0.1:port and add firewall exception to allow
# external access to internal services in PlayOS
def expose_local_port(vm, port):
    port_state_f = f"/tmp/port-{port}-exposed"
    (exists, _) = vm.execute("test -f {port_state_f}")

    if (exists == 0):
        print(f"Port {port} already exposed")
        return

    # enable NAT on loopback
    vm.succeed("sysctl net.ipv4.conf.all.route_localnet=1")

    # forward the port
    vm.succeed("iptables -t nat -A PREROUTING -p tcp " + \
                f"--dport {port} -j DNAT --to-destination 127.0.0.1:{port}")

    # open the port in the firewall
    vm.succeed(f"iptables -A INPUT -p tcp --dport {port} -j ACCEPT")
    vm.succeed("systemctl reload firewall")
    vm.succeed(f"touch {port_state_f}")

# with exponential back-off
async def retry_until_no_exception(func, retries=3, sleep=3.0):
    total_retries = retries
    while True:
        retries -= 1
        try:
            return (await func())
        except Exception as e:
            if (retries > 0):
                print(f"Func failed with {e}, sleeping for {sleep} seconds")
                await asyncio.sleep(sleep)
                sleep *= 2
            else:
                print(f"Func failed with {e}, giving up after {total_retries}")
                raise e

# due to nix sandboxing, network access is isolated, so
# we run a minimal HTTP server for opening in the kiosk
def run_stub_server(port):
    with open("index.html", "w") as f:
        f.write("Hello world")

    server = http.server.HTTPServer(
        ("", port),
        http.server.SimpleHTTPRequestHandler
    )
    print(f"Starting HTTP server on port {port}")
    # Running as a separate process to avoid GIL
    http_p = mp.Process(target=server.serve_forever, daemon=True)
    http_p.start()


async def connect_to_kiosk_debug_engine(vm, guest_cdp_port=None, host_cdp_port=None):
    expose_local_port(vm, guest_cdp_port)

    async def try_connect():
        # connect to Qt WebEngine's CDP debug port
        host_cdp_url = f"http://127.0.0.1:{host_cdp_port}/json/version"
        cdp_info = requests.get(host_cdp_url).json()
        ws_url = cdp_info['webSocketDebuggerUrl']
        browser = await pyppeteer.launcher.connect(browserWSEndpoint=ws_url)
        return browser

    # Sometimes try_connect fails with connection reset by peer, 
    # probably due to firewall restart when doing `expose_local_port`?
    return await retry_until_no_exception(try_connect)

