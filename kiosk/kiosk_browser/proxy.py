"""Monitor proxy changes and automatically apply changes in Qt application.
"""
import dbus
import logging
import threading
from PyQt6.QtNetwork import QNetworkProxy
from dataclasses import dataclass
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib
from proxy_utils import get_current_proxy


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
