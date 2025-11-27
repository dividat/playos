from PyQt6 import QtWidgets, QtCore, QtGui
from PyQt6.QtWidgets import QApplication
from PyQt6.QtCore import Qt
import time
import logging
from dataclasses import dataclass
from collections.abc import Callable
import os

from kiosk_browser import browser_widget, captive_portal, dialogable_widget
from kiosk_browser.keyboard_widget import KeyboardWidget
from kiosk_browser.long_press import LongPressEvents, KeyCombination
from kiosk_browser.focus_object_tracker import FocusObjectTracker

# Conditionally import mock or real modules based on environment
if os.getenv("KIOSK_USE_MOCKS"):
    from kiosk_browser import mock_proxy as proxy_module
    from kiosk_browser.mock_keyboard_detector import KeyboardDetector
else:
    from kiosk_browser import proxy as proxy_module
    from kiosk_browser.keyboard_detector import KeyboardDetector


@dataclass
class ShortcutDef:
    name: str
    keys: set[Qt.Key]
    action: Callable[[], None]

    def to_combo(self):
        return KeyCombination(name=self.name, keys=frozenset(self.keys))


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

        # FocusObjectTracker
        self._focus_object_tracker = FocusObjectTracker(self)

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
            parent = self,
            keyboard_detector=self._keyboard_detector)
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
            ),
            # The DT-007c remote control has Escape+Down mapped to F20 in the firmware
            ShortcutDef(
                name = "hard-refresh-alt",
                keys = { Qt.Key.Key_F20 },
                action = self._browser_widget.hard_refresh
            )
        ]

        long_press_combos = [shortcut.to_combo() for shortcut in long_press_shortcuts]
        long_press_actions = { shortcut.name: shortcut.action for shortcut in long_press_shortcuts }

        # installed on QApplication.instance() to ensure LongPressEvents gets to see all events first
        self._long_press_events = LongPressEvents(
            QApplication.instance(), long_press_combos, self._focus_object_tracker)
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
                self._keyboardWidget = KeyboardWidget(self, self._focus_object_tracker)
            else:
                logging.warning(
                    "All physical keyboards disconnected just now, "
                    "but KeyboardWidget already initialized - this should not happen"
                )

    def _open_settings(self):
        self._browser_widget.load(self._settings_url, inject_spatial_navigation_scripts=True)
        self._dialogable_browser.decorate("System Settings")


    # Toggles setting view
    def _toggle_settings(self):
        # Default actions which are always available
        if self._dialogable_browser.is_decorated():
            self._close_dialog()
        else:
            self._open_settings()

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

    # Similar to QWidget.focusNextPrevChild, but:
    # - uses the currently focused widget QApplication.focusWidget() as the starting point
    # - avoids calling focusNextPrevChild, which is a protected method and
    #   raises a RuntimeError when called for QWidget's not created from PyQt
    # - prevents wrap-around assuming `bottom_widget` is the last focusable widget
    #   in the focus chain
    def _focus_next_prev_wihtout_wrapping(self, is_forward: bool) -> bool:
        focusWidget = QApplication.focusWidget()

        # Handle bizarre dev cases, e.g. kiosk window minimized, but DevTools open
        if focusWidget is None:
            return False

        bottom_widget = self._browser_widget

        next_prev = find_next_prev_focusable_widget(focusWidget, is_forward)

        if next_prev is None:
            return False

        # If going backwards would wrap around to bottom_widget, do nothing
        if not is_forward and bottom_widget.isAncestorOf(next_prev):
                return False

        # If going forward and already focused on bottom_widget or its child, do nothing
        elif is_forward and bottom_widget.isAncestorOf(focusWidget):
                return False

        next_prev.setFocus()
        return True

    # Centralised handling of arrow Up/Down focus shifting.
    #
    # If a key press event for Up/Down bubbled up to here, try to shift focus
    # (i.e. treat Down as Tab, Up as Shift+Tab), but prevent wrap around.
    #
    # Note: Currently not handling Left/Right as widgets/dialogs are only
    # stacked vertically.
    def keyPressEvent(self, event):
        handled = False

        if event.key() == Qt.Key.Key_Down:
            handled = self._focus_next_prev_wihtout_wrapping(True)
        elif event.key() == Qt.Key.Key_Up:
            handled = self._focus_next_prev_wihtout_wrapping(False)

        if handled:
            return
        else:
            super().keyPressEvent(event)


## Helpers

# Find the next/prev element in the focus chain that is visible, enabled and
# accepts TabFocus. This is simpler than what Qt does in focusNextPrevChild()
# but works for our purposes.
def find_next_prev_focusable_widget(initial: QtWidgets.QWidget, is_forward: bool) -> None | QtWidgets.QWidget:
    def iter_next_prev(w):
        if is_forward:
            return w.nextInFocusChain()
        else:
            return w.previousInFocusChain()

    next_prev = initial

    while next_prev := iter_next_prev(next_prev):
        if next_prev == initial:
            break

        if next_prev.isEnabled() and next_prev.isVisible() and next_prev.focusPolicy() & Qt.FocusPolicy.TabFocus:
            return next_prev

    # we looped around without finding focusable items
    return None
