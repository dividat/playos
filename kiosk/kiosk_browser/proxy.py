"""Monitor proxy changes and automatically apply changes in Qt application.
"""

import collections
import dbus
import logging
import threading
import urllib
from PyQt6.QtNetwork import QNetworkProxy
from dataclasses import dataclass
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

@dataclass
class Credentials:
    username: str
    password: str

@dataclass
class ProxyConf:
    hostname: str
    port: int
    credentials: Credentials | None

@dataclass
class Service:
    state: str
    proxy: ProxyConf | None

def parse_service(service: dbus.Struct) -> Service | None:
    if len(service) >= 2 and 'State' in service[1]:
        return Service(service[1]['State'], extract_manual_proxy(service[1]))
    else:
        return None

def extract_manual_proxy(service_conf: dbus.Dictionary) -> ProxyConf | None:
    if 'Proxy' in service_conf:
        proxy = service_conf['Proxy']
        if 'Method' in proxy and 'Servers' in proxy:
            method = proxy['Method']
            servers = proxy['Servers']
            if method == 'manual' and len(servers) >= 1:
                return parse_proxy_url(servers[0])
            else:
                return None
        else:
            return None
    else:
        return None

def parse_proxy_url(url: str) -> ProxyConf | None:
    if url.startswith('http://'):
        parsed = urllib.parse.urlparse(url)
    else:
        parsed = urllib.parse.urlparse(f'http://{url}')

    if parsed.hostname != None and parsed.port != None:
        assert isinstance(parsed.hostname, str)
        assert isinstance(parsed.port, int)

        if parsed.username != None and parsed.password != None:
            assert isinstance(parsed.username, str)
            assert isinstance(parsed.password, str)

            username = urllib.parse.unquote(parsed.username)
            password = urllib.parse.unquote(parsed.password)
            return ProxyConf(parsed.hostname, parsed.port, Credentials(username, password))
        else:
            return ProxyConf(parsed.hostname, parsed.port, None)
    else:
        logging.warning(f"Hostname or port missing in proxy url")
        return None

def get_current_proxy(bus) -> ProxyConf | None:
    """Get current proxy from dbus.

    Return the proxy of a connected service preferentially, or of a ready
    service.

    Return None if Connman is not installed (DBusException).
    """

    try:
        client = dbus.Interface(
            bus.get_object('net.connman', '/'),
            'net.connman.Manager')

        # List services, each service is a (id, properties) struct
        services = [parse_service(s) for s in client.GetServices()]

        # The service with the default route will always be sorted at the top of
        # the list. (From connman doc/overview-api.txt)
        default_service = find(lambda s: s.state in ['online', 'ready'], services)

        if default_service:
            return default_service.proxy
        else:
            return None

    except dbus.exceptions.DBusException:
        return None

def find(f, xs):
    return next((x for x in xs if f(x)), None)

def set_proxy_in_qt_app(hostname, port):
    network_proxy = QNetworkProxy()
    network_proxy.setType(QNetworkProxy.ProxyType.HttpProxy)
    network_proxy.setHostName(hostname)
    network_proxy.setPort(port)
    QNetworkProxy.setApplicationProxy(network_proxy)
    logging.info(f"Set proxy to {hostname}:{port} in Qt application")

def set_no_proxy_in_qt_app():
    QNetworkProxy.setApplicationProxy(QNetworkProxy())
    logging.info(f"Set no proxy in Qt application")

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
            self._update(get_current_proxy(self._bus))

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
