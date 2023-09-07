from PyQt5 import QtWidgets, QtCore
from dataclasses import dataclass

from kiosk_browser import browser_widget, captive_portal
from kiosk_browser import proxy as proxy_module
from kiosk_browser import webview_dialog

@dataclass
class Closed:
    pass

@dataclass
class Settings:
    dialog: QtWidgets.QDialog

@dataclass
class CaptivePortal:
    dialog: QtWidgets.QDialog

Dialog = Closed | Settings | CaptivePortal

class MainWidget(QtWidgets.QWidget):

    def __init__(self, kiosk_url, settings_url, toggle_settings_key):
        super(MainWidget, self).__init__()

        # White background color (default is gray)
        self.setStyleSheet("background-color: white;")

        proxy = proxy_module.Proxy()
        proxy.start_monitoring_daemon()

        self._dialog = Closed()
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
        if self._captive_portal_message.parentWidget() == None:
            match self._dialog:
                case CaptivePortal(_):
                    pass
                case _:
                    self._layout.addWidget(self._captive_portal_message)

    def _toggle_settings(self):
        match self._dialog:
            case Closed():
                self._show_settings()
            case _:
                self._close_dialog()

    def _show_settings(self):
        self._browser_widget.show_overlay()
        dialog = webview_dialog.widget(
                parent = self, 
                title = "System Settings", 
                url = self._settings_url, 
                additional_close_keys = [self._toggle_settings_key],
                on_close = lambda: self._close_dialog()
            )
        self._dialog = Settings(dialog)
        # Open modeless to allow accessing captive portal message banner
        # https://doc.qt.io/qtforpython-5/PySide2/QtWidgets/QDialog.html#modeless-dialogs
        # Focus directly to allow tabbing
        dialog.show()
        dialog.raise_()
        dialog.activateWindow()

    def _show_captive_portal(self):
        self._close_dialog(reload_browser_widget = False)
        self._browser_widget.show_overlay()
        self._captive_portal_message.setParent(None)
        dialog = webview_dialog.widget(
                parent = self, 
                title = "Network Login", 
                url = self._captive_portal_url,
                additional_close_keys = [self._toggle_settings_key],
                on_close = lambda: self._close_dialog()
            )
        self._dialog = CaptivePortal(dialog)
        dialog.exec_()

    def _close_dialog(self, reload_browser_widget = True):
        match self._dialog:
            case Settings(dialog):
                dialog.close()
                self._dialog = Closed()
            case CaptivePortal(dialog):
                dialog.close()
                self._dialog = Closed()
        if reload_browser_widget:
            self._browser_widget.reload()
