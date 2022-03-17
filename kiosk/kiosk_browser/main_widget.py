from enum import Enum
from PyQt5.QtCore import pyqtSlot, Qt, QUrl
from PyQt5.QtGui import QKeySequence
from PyQt5.QtWidgets import QWidget, QPushButton, QBoxLayout, QShortcut

from kiosk_browser import browser_widget, captive_portal_message, captive_portal
from kiosk_browser import proxy as proxy_module
from kiosk_browser import webview_dialog

class MainWidget(QWidget):

    def __init__(self, kiosk_url, parameters_url, toggle_parameters_key):
        super(MainWidget, self).__init__()

        proxy = proxy_module.Proxy()
        proxy.start_monitoring_daemon()

        self._captive_portal_url = ''
        self._kiosk_url = kiosk_url
        self._parameters_url = parameters_url
        self._toggle_parameters_key = toggle_parameters_key
        self._browser_widget = browser_widget.BrowserWidget(self._kiosk_url, proxy.get_current)
        self._is_captive_portal_visible = False
        self._captive_portal_message = captive_portal_message.CaptivePortalMessage(self._toggle_captive_portal)

        self._layout = QBoxLayout(QBoxLayout.BottomToTop)
        self._layout.setContentsMargins(0, 0, 0, 0)
        self._layout.setSpacing(0)
        self._layout.addWidget(self._browser_widget)

        # Start captive portal when state is initialized
        self._captive_portal = captive_portal.CaptivePortal(proxy.get_current, self.set_captive_portal_url)
        self._captive_portal.start_monitoring_daemon()

        QShortcut(toggle_parameters_key, self).activated.connect(self._show_parameters)

        self.setLayout(self._layout)
        self.show()

    def set_captive_portal_url(self, url):
        self._captive_portal_url = url
        if url == '' and not self._is_captive_portal_visible:
            self._captive_portal_message.setParent(None)
        else:
            self._update_captive_portal_message()
            self._layout.addWidget(self._captive_portal_message)

    # Private

    def _show_parameters(self):
        webview_dialog.widget(self, "Parameters", self._parameters_url, self._toggle_parameters_key).exec_()

    def _toggle_captive_portal(self):
        if self._is_captive_portal_visible:
            if not self._captive_portal.is_captive():
                self._captive_portal_message.setParent(None)
            self._browser_widget.load(self._kiosk_url)
        else:
            self._browser_widget.load(QUrl(self._captive_portal_url))
        self._is_captive_portal_visible = not self._is_captive_portal_visible
        self._update_captive_portal_message()

    def _update_captive_portal_message(self):
        if self._is_captive_portal_visible:
            self._captive_portal_message.setCloseMessage(self._captive_portal.is_captive())
        else:
            self._captive_portal_message.setOpenMessage()
