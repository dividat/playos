from PyQt5 import QtWidgets, QtCore

from kiosk_browser import browser_widget, webview_dialog, captive_portal, proxy as proxy_module

class MainWidget(QtWidgets.QWidget):

    def __init__(self, kiosk_url, settings_url, toggle_settings_key):
        super(MainWidget, self).__init__()

        proxy = proxy_module.Proxy()
        proxy.start_monitoring_daemon()

        self._kiosk_url = kiosk_url
        self._settings_url = settings_url
        self._toggle_settings_key = toggle_settings_key
        self._browser_widget = browser_widget.BrowserWidget(self._kiosk_url, proxy.get_current)

        # Settings dialog
        self._settings_dialog = webview_dialog.WebviewDialog(
                self, 
                "System Settings", 
                self._settings_url, 
                additional_close_keys = [self._toggle_settings_key],
                on_close = lambda: self._browser_widget.reload())

        self._layout = QtWidgets.QBoxLayout(QtWidgets.QBoxLayout.BottomToTop)
        self._layout.setContentsMargins(0, 0, 0, 0)
        self._layout.setSpacing(0)
        self._layout.addWidget(self._browser_widget)

        # Captive portal
        self._is_captive_portal_dialog_open = False
        self._captive_portal_url = ''
        self._captive_portal_message = captive_portal.open_message(self._show_captive_portal)
        self._captive_portal = captive_portal.CaptivePortal(proxy.get_current, self._show_captive_portal_message)
        self._captive_portal.start_monitoring_daemon()

        # Captive portal dialog
        self._captive_portal_dialog = webview_dialog.WebviewDialog(
                self, 
                "Network Login", 
                self._captive_portal_url,
                additional_close_keys = [],
                on_close = self._on_captive_portal_dialog_close)

        QtWidgets.QShortcut(toggle_settings_key, self).activated.connect(self._show_settings)

        self.setLayout(self._layout)
        self.show()

    # Private

    def _show_captive_portal_message(self, url):
        """ Invite to open dialog to connect to captive portal.
        """
        self._captive_portal_url = QtCore.QUrl(url)
        if self._captive_portal_message.parentWidget() == None and not self._is_captive_portal_dialog_open:
            self._layout.addWidget(self._captive_portal_message)

    def _show_settings(self):
        """ Show System Settings dialog.
        """
        self._settings_dialog.show()

    def _show_captive_portal(self):
        """ Show Network Login to captive portal.
        """
        self._is_captive_portal_dialog_open = True
        self._captive_portal_message.setParent(None)
        self._captive_portal_dialog.show()

    def _on_captive_portal_dialog_close(self):
        self._is_captive_portal_dialog_open = False
        self._browser_widget.reload()
