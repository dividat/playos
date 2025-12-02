"""Mock keyboard detector for non-Linux platforms or testing."""

import logging
import os

from PyQt6.QtCore import QObject, pyqtProperty, pyqtSignal


class KeyboardDetector(QObject):
    """
    Mock implementation of KeyboardDetector for platforms without evdev/pyudev.

    Always reports no keyboard available, which will enable the virtual keyboard.
    """

    # Note: cannot use the callback directly, because the monitor is run in a
    # different thread. So instead we introduce a Qt signal.
    keyboard_available_changed = pyqtSignal(bool)

    _keyboard_available: None | bool

    # Needs to be a property to be readable in QWebChannel (see kiosk.injected_scripts)
    @pyqtProperty(bool, notify=keyboard_available_changed)
    def keyboard_available(self):
        return self._keyboard_available

    @keyboard_available.setter  # type: ignore # see https://github.com/python/mypy/issues/9911
    def keyboard_available(self, value):
        if self._keyboard_available != value:
            self._keyboard_available = value
            self.keyboard_available_changed.emit(self._keyboard_available)

    def __init__(self, parent):
        super().__init__(parent)

        logging.info("Using mock keyboard detector - virtual keyboard will be enabled")

        # Always report no keyboard available to enable virtual keyboard
        self._keyboard_available = bool(os.getenv("KIOSK_MOCK_DISABLE_VKB"))
