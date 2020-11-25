"""Ask connman for the manual proxy of the service that connects automatically.
"""

import dbus
import time

bus = dbus.SystemBus()

client = dbus.Interface(
    bus.get_object("net.connman", "/"),
    "net.connman.Manager")

def wait_for_connman():
    # Waiting for connman, as it does not return the services until some
    # seconds after startup (~4 seconds).
    for i in range(0, 20):
        if client.GetServices():
            break
        else:
            time.sleep(0.5)

wait_for_connman()

autoconnect_services = [s for s in client.GetServices() if s[1]['AutoConnect'] == 1]

if autoconnect_services:
    service = autoconnect_services[0][1]
    proxy = service['Proxy']

    if proxy['Method'] == 'manual':
        proxy_url = proxy['Servers'][0]
        if proxy_url.startswith("http://"):
            print(proxy_url)
        else:
            print(f"http://{proxy_url}")
