from PyQt5 import QtWidgets, QtCore

from kiosk_browser import browser_widget, captive_portal
from kiosk_browser import proxy as proxy_module
from kiosk_browser import webview_dialog

class MainWidget(QtWidgets.QWidget):

    def __init__(self, kiosk_url, settings_url, toggle_settings_key):
        super(MainWidget, self).__init__()

        proxy = proxy_module.Proxy()
        proxy.start_monitoring_daemon()

        self._settings_url = settings_url
        self._toggle_settings_key = toggle_settings_key
        self._browser_widget = browser_widget.BrowserWidget(
                url = kiosk_url, 
                get_current_proxy = proxy.get_current, 
                parent = self)

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

        QtWidgets.QShortcut(toggle_settings_key, self).activated.connect(self._show_settings)

        self.setLayout(self._layout)
        self.show()

    # Private

    def _show_captive_portal_message(self, url):
        self._captive_portal_url = QtCore.QUrl(url)
        if self._captive_portal_message.parentWidget() == None and not self._is_captive_portal_dialog_open:
            self._layout.addWidget(self._captive_portal_message)

    def _show_settings(self):
        self._browser_widget.show_blank_page()
        webview_dialog.widget(
                parent = self, 
                title = "System Settings", 
                url = self._settings_url, 
                additional_close_keys = [self._toggle_settings_key],
                on_close = self._browser_widget.reload
            ).exec_()

    def _show_captive_portal(self):
        self._browser_widget.show_blank_page()
        self._is_captive_portal_dialog_open = True
        self._captive_portal_message.setParent(None)
        webview_dialog.widget(
                parent = self, 
                title = "Network Login", 
                url = self._captive_portal_url,
                additional_close_keys = [],
                on_close = self._on_captive_portal_dialog_close
            ).exec_()

    def _on_captive_portal_dialog_close(self):
        self._is_captive_portal_dialog_open = False
        self._browser_widget.reload()
