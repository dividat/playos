from PyQt6 import QtWidgets, QtCore, QtGui
import time
import logging

from kiosk_browser import browser_widget, captive_portal, dialogable_widget, proxy as proxy_module

class MainWidget(QtWidgets.QWidget):
    """ Show website from kiosk_url.

    - Show settings in a dialog using a shortcut or long pressing Menu.
    - Show toolbar message when captive portal is detected, opening it in a dialog.
    - Use proxy configured in Connman.
    """

    def __init__(self, kiosk_url: str, settings_url: str,
                 toggle_settings_key: str, fullscreen: bool):
        super(MainWidget, self).__init__()
        # Display
        self._primary_screen = None
        self._fullscreen = fullscreen

        # Proxy
        proxy = proxy_module.Proxy()
        proxy.start_monitoring_daemon()

        # Menu press
        self._menu_press_since = None
        self._menu_press_delay_seconds = 1.5

        # Browser widget
        self._kiosk_url = kiosk_url
        self._settings_url = settings_url
        self._dialogable_browser = dialogable_widget.DialogableWidget(
            parent = self,
            inner_widget = browser_widget.BrowserWidget(
                url = kiosk_url,
                get_current_proxy = proxy.get_current,
                parent = self),
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

        # Look at events with the eventFilter function
        self.installEventFilter(self)

    def closeEvent(self, event):
        event.accept()

        # Unset page in web view to avoid it outliving the browser profile
        self._dialogable_browser.inner_widget()._webview.setPage(None)

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

    def eventFilter(self, source, event):
        # Toggle settings with a long press on the Menu key
        if event.type() == QtCore.QEvent.Type.ShortcutOverride:
            if event.key() == QtCore.Qt.Key.Key_Menu:
                if not event.isAutoRepeat():
                    self._menu_press_since = time.time()
                elif self._menu_press_since is not None and time.time() - self._menu_press_since > self._menu_press_delay_seconds:
                    self._menu_press_since = None
                    self._toggle_settings()
        elif event.type() == QtCore.QEvent.Type.KeyRelease:
            if event.key() == QtCore.Qt.Key.Key_Menu and not event.isAutoRepeat():
                self._menu_press_since = None

        return super(MainWidget, self).eventFilter(source, event)

    def handle_screen_change(self, new_primary):
        if self._primary_screen is not None:
            logging.info(f"Primary screen changed from: {self._primary_screen.name()} to {new_primary.name()}")
            self._primary_screen.geometryChanged.disconnect()

        self._primary_screen = new_primary
        self._primary_screen.geometryChanged.connect(self._resize_to_screen)
        self._resize_to_screen()

    def _resize_to_screen(self):
        screen_size = self._primary_screen.size() # type: ignore
        logging.info(f"Resizing widget based on new screen size: {screen_size}")
        if self._fullscreen:
            # Without a Window Manager, showFullScreen does not work under X,
            # so set the window size to the primary screen size.
            self.resize(screen_size)
            self.showFullScreen()
        else:
            self.resize(QtCore.QSize(round(screen_size.width() / 2), round(screen_size.height() / 2)))
            self.show()
