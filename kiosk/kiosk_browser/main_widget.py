from PyQt6 import QtWidgets, QtCore, QtGui

from kiosk_browser import browser_widget, captive_portal, dialogable_widget
from system import System
import platform

class MainWidget(QtWidgets.QWidget):
    """ Show website at kiosk_url.

    - Show settings in dialog using shortcut.
    - Show message when captive portal is detected, allowing to show in dialog.
    - Use proxy configured in Connman.
    """

    def __init__(self, kiosk_url: str, settings_url: str, toggle_settings_key: str):
        super(MainWidget, self).__init__()

        if platform.system() in ['Linux']:
            from dbus_proxy import DBusProxy as Proxy
            system = System()
        else:
            from proxy import Proxy
            import os
            system = System(name = "PlayOS",
                            version = os.getenv("PLAYOS_VERSION","1.0.0-dev"))

        # Proxy
        proxy = Proxy()
        proxy.start_monitoring_daemon()

        # Browser widget
        self._kiosk_url = kiosk_url
        self._settings_url = settings_url
        self._dialogable_browser = dialogable_widget.DialogableWidget(
            parent = self,
            inner_widget = browser_widget.BrowserWidget(
                url = kiosk_url,
                get_current_proxy = proxy.get_current,
                parent = self,
                system = system),
            on_close = self._close_dialog)

        # Captive portal
        self._captive_portal_url = ''
        self._is_captive_portal_open = False
        self._captive_portal_message = captive_portal.OpenMessage(self._show_captive_portal, self)
        self._captive_portal = captive_portal.CaptivePortal(proxy.get_current, self._show_captive_portal_message)
        self._captive_portal.start_monitoring_daemon()

        # Layout
        self._layout = QtWidgets.QVBoxLayout()
        self._layout.setContentsMargins(0, 0, 0, 0)
        self._layout.setSpacing(0)
        self._layout.addWidget(self._captive_portal_message)
        self._layout.addWidget(self._dialogable_browser)
        self.setLayout(self._layout)

        # Shortcuts
        QtGui.QShortcut(toggle_settings_key, self).activated.connect(self._toggle_settings)

    # Private

    def _toggle_settings(self):
        if self._dialogable_browser.is_decorated():
            self._close_dialog()
        else:
            self._dialogable_browser.inner_widget().load(self._settings_url)
            self._dialogable_browser.decorate("System Settings")

    def _show_captive_portal_message(self, url: str):
        self._captive_portal_url = QtCore.QUrl(url)
        if not self._captive_portal_message.is_open() and not self._is_captive_portal_open:
            self._captive_portal_message.show()

    def _show_captive_portal(self):
        self._close_dialog()
        self._captive_portal_message.hide()
        self._dialogable_browser.inner_widget().load(self._captive_portal_url)
        self._dialogable_browser.decorate("Network Login")
        self._is_captive_portal_open = True

    def _close_dialog(self):
        if self._dialogable_browser.is_decorated():
            self._dialogable_browser.undecorate()
            self._dialogable_browser.inner_widget().load(self._kiosk_url)
            if self._is_captive_portal_open:
                self._is_captive_portal_open = False
