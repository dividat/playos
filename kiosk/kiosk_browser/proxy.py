"""Monitor proxy changes and automatically apply changes in Qt application.

A ConnMan service, given from Dbus, has the following type:

type service = [ path, service_config ]

type service_config = dict {
  'Type': str,
  'Security': list[str],
  'State': str,
  'Strength': int,
  'Favorite': bool,
  'Immutable': bool,
  'AutoConnect': bool,
  'Name': str,
  'Ethernet': dict({ 'Method': str }),
  'Interface': str,
  'Address': str,
  'MTU': int,
  'IPv4': dict({ 'Method': str, 'Address': str, 'Netmask': str, 'Gateway': str }),
  'IPv4.Configuration': dict({ 'Method': str }),
  'IPv6': dict({ 'Method': str, 'Address': str, 'PrefixLength': int, 'Privacy': str }),
  'IPv6.Configuration': dict({ 'Method': str, 'Privacy': str }),
  'Nameservers': list[str],
  'Nameservers.Configuration': list,
  'Timeservers': list,
  'Timeservers.Configuration': list,
  'Domains': list,
  'Domains.Configuration': list,
  'Proxy': proxy,
  'Proxy.Configuration': proxy,
  'mDNS': bool,
  'mDNS.Configuration': bool,
  'Provider': dict,
}

type proxy = direct | auto | manual

type direct = dict({
    'Method': 'Direct'
})

type auto = dict({
    'Method': 'Auto',
    'URL': str
})

type manual = dict({
  'Method': 'Manual',
  'Servers': list[str],
  'Exclude': list[str]
})
"""

import collections
import dbus
import logging
import threading
import urllib
from PyQt5.QtNetwork import QNetworkProxy
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

ProxyConfig = collections.namedtuple('ProxyConfig', ['hostname', 'port', 'username', 'password'])

def parse_url(url):
    if url.startswith('http://'):
        parsed = urllib.parse.urlparse(url)
    else:
        parsed = urllib.parse.urlparse(f'http://{url}')

    if parsed.hostname != None and parsed.port != None:
        return ProxyConfig(
            parsed.hostname,
            parsed.port,
            (urllib.parse.unquote(parsed.username) if parsed.username != None else None),
            (urllib.parse.unquote(parsed.password) if parsed.password != None else None)
        )
    else:
        logging.warn(f"Hostname or port missing in proxy url")
        return None

def has_service_state_in(service, states: list[str]):
    """Check that service has its state in the given list."""
    return len(service) >= 2 and 'State' in service[1] and service[1]['State'] in states

def extract_manual_proxy(service):
    """Extract manual proxy from service."""
    if len(service) >= 2:
        config = service[1]
        if 'Proxy' in config:
            proxy = config['Proxy']
            if 'Method' in proxy and 'Servers' in proxy:
                method = proxy['Method']
                servers = proxy['Servers']
                if method == 'manual' and len(servers) >= 1:
                    return parse_url(servers[0])

def get_current_proxy(bus):
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
        services = client.GetServices()

        # The service with the default route will always be sorted at the top of
        # the list. (From connman doc/overview-api.txt)
        default_service = find(lambda s: has_service_state_in(s, ['online', 'ready']), services)

        if default_service:
            return extract_manual_proxy(default_service)

    except dbus.exceptions.DBusException:
        return None

def find(f, xs):
    return next((x for x in xs if f(x)), None)

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
