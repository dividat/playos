#!/usr/bin/env python3
"""
LLM-generated script for mocking connman in controller testing, presented as is.

Currently supports easily producing different types of net.`connman.GetServices()`
outputs. To modify the output, change the script and restart. In particular, you
probably want to match the ETH_INTERFACE_* and WIFI_INTERFACE names to your
hardware.

You either need to run this with `sudo` (if your system already has connman
installed) or ensure you have an appropriate D-BUS policy for your user:

    $ cat /etc/dbus-1/system.d/mock_connman.conf
    <!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
     "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
    <busconfig>
      <!-- Allow YOUR_USER to own the net.connman name -->
      <policy user="YOUR_USER">
        <allow own="net.connman"/>
        <allow send_destination="net.connman"/>
      </policy>

      <!-- Allow anyone to send messages to the mock -->
      <policy context="default">
        <allow send_destination="net.connman"/>
      </policy>
    </busconfig>

Relies on dbus-python and pygobject, use `nix-shell -p python3Packages.dbus-python python3Packages.pygobject3`
if you don't have it.
"""

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib
import sys

# Interface names for associating the services with, ensure they match
# your `ip link` output if you want an interface to appear "connected"
ETH_INTERFACE_1 = "enp0s31f6"
ETH_INTERFACE_2 = "enp0s31f7"
WIFI_INTERFACE = "wlp0s20f3"

# ---------------------------------------------------------
# Mock for net.connman.Technology
# Handles scanning and powering on/off Wifi/Ethernet
# ---------------------------------------------------------
class MockTechnology(dbus.service.Object):
    def __init__(self, bus, object_path, initial_props):
        super().__init__(bus, object_path)
        self.properties = initial_props
        print(f"Mock Technology initialized at {object_path}")

    @dbus.service.method('net.connman.Technology', in_signature='sv', out_signature='')
    def SetProperty(self, name, value):
        print(f"[{self._object_path}] SetProperty called: {name} = {value}")
        self.properties[name] = value

    @dbus.service.method('net.connman.Technology', in_signature='', out_signature='')
    def Scan(self):
        print(f"[{self._object_path}] Scan() called. Pretending to scan for networks...")

# ---------------------------------------------------------
# Mock for net.connman.Manager
# ---------------------------------------------------------
class MockConnmanManager(dbus.service.Object):
    def __init__(self, bus, object_path, technologies):
        super().__init__(bus, object_path)
        self.technologies = technologies
        print(f"Mock Connman Manager initialized at {object_path}")

    @dbus.service.method('net.connman.Manager', in_signature='', out_signature='a(oa{sv})')
    def GetTechnologies(self):
        print("[Manager] GetTechnologies() called by a client.")

        tech_list = []
        for path, tech_obj in self.technologies.items():
            dbus_props = dbus.Dictionary(tech_obj.properties, signature='sv')
            tech_list.append((dbus.ObjectPath(path), dbus_props))

        return dbus.Array(tech_list, signature='(oa{sv})')

    @dbus.service.method('net.connman.Manager', in_signature='', out_signature='a(oa{sv})')
    def GetServices(self):
        print("[Manager] GetServices() called by a client.")

        # Helper to generate the required Ethernet dict to satisfy the strict OCaml parser
        def mock_ethernet_dict(iface, mac):
            return dbus.Dictionary({
                'Method': dbus.String('auto'),
                'Interface': dbus.String(iface),
                'Address': dbus.String(mac),
                'MTU': dbus.UInt16(1500) # Must be UInt16 to match OCaml's basic_uint16
            }, signature='sv')

        mock_services = [
            # 1. Ethernet (Online)
            (
                dbus.ObjectPath('/net/connman/service/ethernet_mock'),
                dbus.Dictionary({
                    'Type': dbus.String('ethernet'),
                    'Name': dbus.String('Wired'),
                    'State': dbus.String('ready'),
                    'Favorite': dbus.Boolean(True),
                    'AutoConnect': dbus.Boolean(True),
                    'IPv4': dbus.Dictionary({'Address': '192.168.1.10',
                                             'Netmask': '255.255.255.0', 'Method': 'dhcp'}, signature='sv'),
                    'Security': dbus.Array(['none'], signature='s'),
                    'Nameservers.Configuration': dbus.Array(['8.8.8.8', '1.1.1.1'], signature='s'),
                    'Ethernet': mock_ethernet_dict(ETH_INTERFACE_1, 'AA:BB:CC:DD:EE:01')
                }, signature='sv')
            ),
            # 2. WiFi AP (Ready / Connected)
            (
                dbus.ObjectPath('/net/connman/service/wifi_mock_home'),
                dbus.Dictionary({
                    'Type': dbus.String('wifi'),
                    'Name': dbus.String('HomeNetwork_5G'),
                    'State': dbus.String('ready'),
                    'Strength': dbus.Byte(85),
                    'Favorite': dbus.Boolean(True),
                    'AutoConnect': dbus.Boolean(True),
                    'Security': dbus.Array(['psk'], signature='s'),
                    'IPv4': dbus.Dictionary({'Address': '192.168.2.13',
                                             'Netmask': '255.255.255.0', 'Method': 'dhcp'}, signature='sv'),

                    'IPv6': dbus.Dictionary({
                        'Address': dbus.String('2a00:1eb8:c24f:d71e:2f1:c724:dcfa:d84f'),
                        'PrefixLength': dbus.Byte(1),
                        'Method': dbus.String('dhcp'),
                        'Privacy': dbus.String('foo')
                    }, signature='sv'),
                    'Nameservers.Configuration': dbus.Array(['8.8.8.8'], signature='s'),
                    'Ethernet': mock_ethernet_dict(WIFI_INTERFACE, 'AA:BB:CC:DD:EE:02')
                }, signature='sv')
            ),
            (
                dbus.ObjectPath('/net/connman/service/wifi_mock_other'),
                dbus.Dictionary({
                    'Type': dbus.String('wifi'),
                    'Name': dbus.String('OtherWifi'),
                    'State': dbus.String('idle'),
                    'Strength': dbus.Byte(85),
                    'Favorite': dbus.Boolean(True),
                    'AutoConnect': dbus.Boolean(True),
                    'Security': dbus.Array(['psk'], signature='s'),
                    'Nameservers.Configuration': dbus.Array(['8.8.8.8'], signature='s'),
                    'Ethernet': mock_ethernet_dict(WIFI_INTERFACE, 'AA:BB:CC:DD:EE:02')
                }, signature='sv')
            ),
            (
                dbus.ObjectPath('/net/connman/service/wifi_mock_other1'),
                dbus.Dictionary({
                    'Type': dbus.String('wifi'),
                    'Name': dbus.String('yet another wifi'),
                    'State': dbus.String('idle'),
                    'Strength': dbus.Byte(56),
                    'Favorite': dbus.Boolean(True),
                    'AutoConnect': dbus.Boolean(True),
                    'Security': dbus.Array(['psk'], signature='s'),
                    'Nameservers.Configuration': dbus.Array(['8.8.8.8'], signature='s'),
                    'Ethernet': mock_ethernet_dict(WIFI_INTERFACE, 'AA:BB:CC:DD:EE:02')
                }, signature='sv')
            ),
            (
                dbus.ObjectPath('/net/connman/service/wifi_mock_other2'),
                dbus.Dictionary({
                    'Type': dbus.String('wifi'),
                    'Name': dbus.String('bad signal AP'),
                    'State': dbus.String('idle'),
                    'Strength': dbus.Byte(34),
                    'Favorite': dbus.Boolean(True),
                    'AutoConnect': dbus.Boolean(True),
                    'Security': dbus.Array(['psk'], signature='s'),
                    'Nameservers.Configuration': dbus.Array(['8.8.8.8'], signature='s'),
                    'Ethernet': mock_ethernet_dict(WIFI_INTERFACE, 'AA:BB:CC:DD:EE:02')
                }, signature='sv')
            ),
        ]

        return dbus.Array(mock_services, signature='(oa{sv})')

def main():
    DBusGMainLoop(set_as_default=True)

    try:
        bus = dbus.SystemBus()
        name = dbus.service.BusName('net.connman', bus)

        # 1. Setup Mock Technologies
        wifi_path = '/net/connman/technology/wifi'
        eth_path = '/net/connman/technology/ethernet'

        tech_objects = {
            eth_path: MockTechnology(bus, eth_path, {
                'Name': dbus.String('Wired'),
                'Type': dbus.String('ethernet'),
                'Powered': dbus.Boolean(True),
                'Connected': dbus.Boolean(True),
                'Tethering': dbus.Boolean(False),
            }),
            wifi_path: MockTechnology(bus, wifi_path, {
                'Name': dbus.String('WiFi'),
                'Type': dbus.String('wifi'),
                'Powered': dbus.Boolean(False),
                'Connected': dbus.Boolean(False),
                'Tethering': dbus.Boolean(False),
            })
        }

        # 2. Setup Manager
        manager = MockConnmanManager(bus, '/', tech_objects)

        print("Mock Connman running on the System Bus. Waiting for calls...")

        loop = GLib.MainLoop()
        loop.run()

    except dbus.exceptions.DBusException as e:
        print(f"Failed to claim D-Bus name: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
