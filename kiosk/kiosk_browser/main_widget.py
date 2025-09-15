from PyQt6 import QtWidgets, QtCore, QtGui
from PyQt6.QtWidgets import QPushButton, QDialog, QHBoxLayout, QApplication
from PyQt6.QtCore import Qt
import time
import logging
from dataclasses import dataclass
from collections.abc import Callable

from kiosk_browser import browser_widget, captive_portal, dialogable_widget, proxy as proxy_module
from kiosk_browser.keyboard_widget import KeyboardWidget
from kiosk_browser.keyboard_detector import KeyboardDetector
from kiosk_browser.long_press import LongPressEvents, KeyCombination


@dataclass
class ShortcutDef:
    name: str
    keys: set[Qt.Key]
    action: Callable[[], None]

    def to_combo(self):
        return KeyCombination(name=self.name, keys=frozenset(self.keys))


class MultiActionToggleSettingsDialog(QDialog):
    def __init__(self, parent, actions: dict):
        super().__init__(parent)

        self.setWindowTitle("Choose action")
        layout = QHBoxLayout(self)

        last_button = None
        for action_name, action_callback in actions.items():
            button = QPushButton(action_name)
            button.clicked.connect(action_callback)
            button.clicked.connect(self.accept)
            layout.addWidget(button)
            last_button = button

        if last_button:
            last_button.setDefault(True)
            last_button.setFocus()


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
        self._primary_screen_con = None
        self._fullscreen = fullscreen

        # Proxy
        proxy = proxy_module.Proxy()
        proxy.start_monitoring_daemon()

        # Menu press
        self._menu_press_since = None
        self._menu_press_delay_seconds = 1.5

        # Virtual keyboard
        self._keyboardWidget = None
        self._keyboard_detector = KeyboardDetector(self)
        self._keyboard_detector.keyboard_available_changed.connect(self._toggle_virtual_keyboard)
        self._toggle_virtual_keyboard(self._keyboard_detector.keyboard_available)

        # Browser widget
        self._kiosk_url = kiosk_url
        self._settings_url = settings_url
        self._browser_widget = browser_widget.BrowserWidget(
            url = kiosk_url,
            get_current_proxy = proxy.get_current,
            parent = self)
        self._dialogable_browser = dialogable_widget.DialogableWidget(
            parent = self,
            inner_widget = self._browser_widget,
            on_close = self._close_dialog,
            keyboard_detector = self._keyboard_detector)

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

        # Application shortcuts

        ## Keyboard shortcuts

        # Shortcut to toggle settings (CTRL+SHIFT+12 by default)
        QtGui.QShortcut(toggle_settings_key, self).activated.connect(self._toggle_settings)
        # Shortcut to manually reload webview page
        QtGui.QShortcut('CTRL+R', self).activated.connect(self._browser_widget.reload)
        # Shortcut to perform a hard webview refresh
        QtGui.QShortcut('CTRL+SHIFT+R', self).activated.connect(self._browser_widget.hard_refresh)

        ## Remote Control long-press shortcuts
        long_press_shortcuts = [
            ShortcutDef(
                name = "menu",
                keys = { Qt.Key.Key_Menu },
                action = self._toggle_settings,
            ),
            # close dialog (if any)
            ShortcutDef(
                name = "escape",
                keys = { Qt.Key.Key_Escape },
                action = self._close_dialog,
            ),
            ShortcutDef(
                name = "hard-refresh",
                keys = { Qt.Key.Key_Escape, Qt.Key.Key_Down },
                action = self._browser_widget.hard_refresh
            )
        ]

        long_press_combos = [shortcut.to_combo() for shortcut in long_press_shortcuts]
        long_press_actions = { shortcut.name: shortcut.action for shortcut in long_press_shortcuts }

        # installed on QApplication.instance() to ensure LongPressEvents gets to see all events first
        self._long_press_events = LongPressEvents(QApplication.instance(), long_press_combos)
        self._long_press_events.long_press_combo.connect(
            lambda combo_name: long_press_actions[combo_name]()
        )


    def closeEvent(self, event):
        self._browser_widget.closeEvent(event)
        return super().closeEvent(event)

    # Private

    def _toggle_virtual_keyboard(self, physical_keyboard_is_available):
        if physical_keyboard_is_available:
            if self._keyboardWidget:
                logging.info("Physical keyboard available, disabling virtual keyboard")
                self._keyboardWidget.deleteLater()
                self._keyboardWidget = None

        else:
            if self._keyboardWidget is None:
                logging.info("No physical keyboard, enabling virtual keyboard")
                self._keyboardWidget = KeyboardWidget(self)
            else:
                logging.warning(
                    "All physical keyboards disconnected just now, "
                    "but KeyboardWidget already initialized - this should not happen"
                )

    def _open_settings(self):
        self._browser_widget.load(self._settings_url, inject_spatial_navigation_scripts=True)
        self._dialogable_browser.decorate("System Settings")


    # By default toggles setting view, but when captive portal is detected,
    # shows a modal dialog with several options.
    def _toggle_settings(self):
        actions = {}

        # Default actions which are always available
        if self._dialogable_browser.is_decorated():
            actions['Return to home'] = self._close_dialog
        else:
            actions['Open settings'] = self._open_settings

        # Additional actions:
        if self._captive_portal_message.is_open():
            actions['Network login'] = self._show_captive_portal

        if len(actions) == 1:
            first_action = next(iter(actions.values()))
            first_action()
        else:
            dialog = MultiActionToggleSettingsDialog(self, actions)
            dialog.exec()
            self.activateWindow()


    def _show_captive_portal_message(self, url: str):
        self._captive_portal_url = QtCore.QUrl(url)
        if not self._captive_portal_message.is_open() and not self._is_captive_portal_open:
            self._captive_portal_message.show()

    def _show_captive_portal(self):
        self._close_dialog()
        self._captive_portal_message.hide()
        self._browser_widget.load(self._captive_portal_url,
                                  inject_spatial_navigation_scripts=True,
                                  inject_focus_highlight=True)
        self._dialogable_browser.decorate("Network Login")
        self._is_captive_portal_open = True

    def _close_dialog(self):
        if self._dialogable_browser.is_decorated():
            self._dialogable_browser.undecorate()
            self._browser_widget.load(self._kiosk_url)
            if self._is_captive_portal_open:
                self._is_captive_portal_open = False


    def handle_screen_change(self, new_primary):
        logging.info(f"Primary screen changed to {new_primary.name()}")
        if self._primary_screen_con is not None:
            QtCore.QObject.disconnect(self._primary_screen_con)

        self._primary_screen_con = \
            new_primary.geometryChanged.connect(self._resize_to_screen)

        # Precautionary sleep to allow Chromium to update screens
        time.sleep(1)
        self._resize_to_screen(new_primary.geometry())

    def _resize_to_screen(self, new_geom):
        screen_size = new_geom.size()
        logging.info(f"Resizing widget based on new screen size: {screen_size}")
        if self._fullscreen:
            # Without a Window Manager, showFullScreen does not work under X,
            # so set the window size to the primary screen size.
            self.resize(screen_size)
            self.showFullScreen()
        else:
            self.resize(QtCore.QSize(round(screen_size.width() / 2), round(screen_size.height() / 2)))
            self.show()

    def resizeEvent(self, event):
        if self._keyboardWidget:
            self._keyboardWidget._resize()
        return super().resizeEvent(event)
