"""Monitor proxy changes and automatically apply changes in Qt application"""

import dbus
import logging
import threading
import urllib
from PyQt5.QtNetwork import QNetworkProxy
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

def extract_manual_proxy(config):
    """Extract manual proxy from dbus configuration

    Example configuration:

    dbus.Dictionary({dbus.String('Servers'): dbus.Array([dbus.String('http://localhost:1234')], signature=dbus.Signature('s'), variant_level=1), dbus.String('Excludes'): dbus.Array([], signature=dbus.Signature('s'), variant_level=1), dbus.String('Method'): dbus.String('manual', variant_level=1)}, signature=dbus.Signature('sv'), variant_level=1)"""

    if 'Method' in config:
        method = config['Method']
        if method == 'direct':
            return None
        elif method == 'manual':
            if 'Servers' in config:
                servers = config['Servers']
                if len(servers) >= 1:
                    url = servers[0]
                    if url.startswith('http://'):
                        return url
                    else:
                        return f'http://{url}'
    else:
        return None

def get_current_proxy(bus):
    """Get current proxy from dbus

    Return  the proxy of a ready or connected service."""

    client = dbus.Interface(
        bus.get_object('net.connman', '/'),
        'net.connman.Manager')

    connected_services = [s for s in client.GetServices() if s[1]['State'] in ['ready', 'online']]

    if connected_services:
        service = connected_services[0][1]
        return extract_manual_proxy(service['Proxy'])

def set_proxy_in_qt_app(hostname, port):
    logging.info(f"Set proxy to {hostname}:{port} in Qt application")
    network_proxy = QNetworkProxy()
    network_proxy.setType(QNetworkProxy.HttpProxy)
    network_proxy.setHostName(hostname)
    network_proxy.setPort(port)
    QNetworkProxy.setApplicationProxy(network_proxy)

def set_no_proxy_in_qt_app():
    logging.info(f"Set no proxy in Qt application")
    QNetworkProxy.setApplicationProxy(QNetworkProxy())

class Proxy():

    def __init__(self):
        self._proxy = None

    def start_daemon(self):
        thread = threading.Thread(target=self._set_initial_and_monitor, args=[])
        thread.daemon = True
        thread.start()

    def current(self):
        return self._proxy

    def _set_initial_and_monitor(self):
        DBusGMainLoop(set_as_default=True)

        bus = dbus.SystemBus()

        bus.add_signal_receiver(
            handler_function = self._handler_function,
            bus_name = 'net.connman',
            member_keyword = 'PropertyChanged')

        # Initialize after the monitoring is running, so that we do not miss
        # any proxy modification.
        self._update(get_current_proxy(bus))

        loop = GLib.MainLoop()
        loop.run()

    def _handler_function(self, *args, **kwargs):
        if len(args) >= 2 and args[0] == 'Proxy':
            self._update(extract_manual_proxy(args[1]))

    def _update(self, proxy):
        """Update proxy state and apply it in Qt application"""
        if proxy is not None:
            url = urllib.parse.urlparse(proxy)
            if url.hostname != None and url.port != None:
                self._proxy = url
                set_proxy_in_qt_app(url.hostname, url.port)
            else:
                logging.info(f"Hostname or port missing in proxy url")
                self._proxy = None
                set_no_proxy_in_qt_app()
        else:
            self._proxy = None
            set_no_proxy_in_qt_app()
