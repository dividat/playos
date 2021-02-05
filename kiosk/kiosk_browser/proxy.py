"""Monitor proxy changes and automatically apply changes in Qt application"""

import dbus
import logging
import threading
import urllib
from PyQt5.QtNetwork import QNetworkProxy
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

def parse_url(url):
    if url.startswith('http://'):
        parsed = urllib.parse.urlparse(url)
    else:
        parsed = urllib.parse.urlparse(f'http://{url}')

    if parsed.hostname != None and parsed.port != None:
        return parsed
    else:
        logging.warn(f"Hostname or port missing in proxy url")
        return None

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
                    return parse_url(servers[0])
    else:
        return None

def get_current_proxy(bus):
    """Get current proxy from dbus

    Return the proxy of a connected service preferentially, or of a ready
    service.
    """

    client = dbus.Interface(
        bus.get_object('net.connman', '/'),
        'net.connman.Manager')

    # List services, each service is a (id, properties) struct
    services = client.GetServices()
    online_services = [s for s in services if s[1]['State'] == 'online']
    ready_services = [s for s in services if s[1]['State'] == 'ready']
    online_or_ready_services = online_services + ready_services

    if online_or_ready_services:
        return extract_manual_proxy(online_or_ready_services[0][1]['Proxy'])

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
        DBusGMainLoop(set_as_default=True)
        self._bus = dbus.SystemBus()
        self._proxy = get_current_proxy(self._bus)

    def start_monitoring_daemon(self):
        """Use initial proxy in Qt application and watch for changes."""
        self._use_in_qt_app()
        thread = threading.Thread(target=self._monitor, args=[])
        thread.daemon = True
        thread.start()

    def get_current(self):
        return self._proxy

    def _monitor(self):
        self._bus.add_signal_receiver(
            handler_function = self._on_property_changed,
            bus_name = 'net.connman',
            member_keyword = 'PropertyChanged')

        # Update just after monitoring is on, so that we do not miss any proxy
        # modification that could have happen before.
        self._update(get_current_proxy(self._bus))

        loop = GLib.MainLoop()
        loop.run()

    def _on_property_changed(self, *args, **kwargs):
        if len(args) >= 2 and args[0] == 'Proxy':
            self._update(extract_manual_proxy(args[1]))

    def _update(self, new_proxy):
        """Update the proxy and use in Qt application, if the value has changed."""
        if new_proxy != self._proxy:
            self._proxy = new_proxy
            self._use_in_qt_app()

    def _use_in_qt_app(self):
        if self._proxy is not None:
            set_proxy_in_qt_app(self._proxy.hostname, self._proxy.port)
        else:
            set_no_proxy_in_qt_app()
