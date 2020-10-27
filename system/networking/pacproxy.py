import dbus

"""Ask pacrunner for the proxy to use with https://dividat.com.

Pacrunner can currently only be configured with a fixed proxy URL through the
controller. We are not using its PAC capabilities.

So, we don’t need to query pacrunner before each request, because the proxy is
fixed, it does not depend on individual HTTP requests.

We’re using https://dividat.com, but we could have used any valid URL.
"""

bus = dbus.SystemBus()

client = dbus.Interface(
    bus.get_object("org.pacrunner", "/org/pacrunner/client"),
    "org.pacrunner.Client")

result = "%s" % client.FindProxyForURL("https://dividat.com", "127.0.0.1")

if result.startswith("PROXY"):
    print(result[6:])
