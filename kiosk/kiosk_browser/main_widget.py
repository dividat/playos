from PyQt5 import QtWidgets, QtCore
from enum import Enum, auto

from kiosk_browser import browser_widget, captive_portal
from kiosk_browser import proxy as proxy_module
from kiosk_browser import webview_dialog

"""
Dialog View being open
"""
class DialogView(Enum):
    CLOSED = auto()
    SETTINGS = auto()
    CAPTIVE_PORTAL = auto()

class MainWidget(QtWidgets.QWidget):

    def __init__(self, kiosk_url, settings_url, toggle_settings_key):
        super(MainWidget, self).__init__()

        # White background color (default is gray)
        self.setStyleSheet("background-color: white;")

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

        # Dialog
        self._dialog_view = DialogView.CLOSED

        # Captive portal
        self._captive_portal_url = ''
        self._captive_portal_message = captive_portal.open_message(self._show_captive_portal)
        self._captive_portal = captive_portal.CaptivePortal(proxy.get_current, self._show_captive_portal_message)
        self._captive_portal.start_monitoring_daemon()

        QtWidgets.QShortcut(toggle_settings_key, self).activated.connect(self._toggle_settings)

        self.setLayout(self._layout)
        self.show()

    # Private

    def _show_captive_portal_message(self, url):
        self._captive_portal_url = QtCore.QUrl(url)
        if self._captive_portal_message.parentWidget() == None and not self._dialog_view == DialogView.CAPTIVE_PORTAL:
            self._layout.addWidget(self._captive_portal_message)

    def _toggle_settings(self):
        if self._dialog_view == DialogView.CLOSED:
            self._show_settings()
        else:
            self._on_dialog_close()

    def _show_settings(self):
        self._browser_widget.show_overlay()
        self._dialog = webview_dialog.widget(
                parent = self, 
                title = "System Settings", 
                url = self._settings_url, 
                additional_close_keys = [self._toggle_settings_key],
                on_close = self._on_dialog_close
            )
        # Open modeless to allow accessing captive portal message banner
        # https://doc.qt.io/qtforpython-5/PySide2/QtWidgets/QDialog.html#modeless-dialogs
        self._dialog.show()
        self._dialog_view = DialogView.SETTINGS

    def _show_captive_portal(self):
        if not self._dialog_view == DialogView.CLOSED:
            self._dialog.close()
        self._browser_widget.show_overlay()
        self._is_captive_portal_dialog_open = True
        self._captive_portal_message.setParent(None)
        self._dialog = webview_dialog.widget(
                parent = self, 
                title = "Network Login", 
                url = self._captive_portal_url,
                additional_close_keys = [self._toggle_settings_key],
                on_close = self._on_dialog_close
            )
        self._dialog.show()
        self._dialog_view = DialogView.CAPTIVE_PORTAL

    def _on_dialog_close(self):
        self._dialog_view = DialogView.CLOSED
        self._browser_widget.reload()
        self._dialog.close()
