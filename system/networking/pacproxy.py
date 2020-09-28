import dbus

bus = dbus.SystemBus()

client = dbus.Interface(
    bus.get_object("org.pacrunner", "/org/pacrunner/client"),
    "org.pacrunner.Client")

result = "%s" % client.FindProxyForURL("https://dividat.com", "127.0.0.1")

if result.startswith("PROXY"):
    print(result[6:])
