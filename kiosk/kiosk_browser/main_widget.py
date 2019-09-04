from enum import Enum
from itertools import cycle
from PyQt5.QtCore import pyqtSlot, Qt, QUrl
from PyQt5.QtGui import QKeySequence
from PyQt5.QtWidgets import QWidget, QPushButton, QBoxLayout, QShortcut

from kiosk_browser import browser_widget, captive_portal_message, connection

class MainWidget(QWidget):

    def __init__(self, urls, toggle_sequence):
        super(MainWidget, self).__init__()

        self._connection = connection.Connection(self.set_captive_portal_url)
        self._captive_portal_url = ''
        self._urls = cycle(urls)
        self._current_url = next(self._urls)
        self._browser_widget = browser_widget.BrowserWidget(self._current_url)
        self._is_captive_portal_visible = False
        self._captive_portal_message = captive_portal_message.CaptivePortalMessage(self._toggle_captive_portal)

        self._layout = QBoxLayout(QBoxLayout.BottomToTop)
        self._layout.setContentsMargins(0, 0, 0, 0)
        self._layout.setSpacing(0)
        self._layout.addWidget(self._browser_widget)

        QShortcut(toggle_sequence, self).activated.connect(self._load_next_url)

        self.setLayout(self._layout)
        self.show()
        self._connection.start_daemon()

    def set_captive_portal_url(self, url):
        self._captive_portal_url = url
        if url == '' and not self._is_captive_portal_visible:
            self._captive_portal_message.setParent(None)
        else:
            self._update_captive_portal_message()
            self._layout.addWidget(self._captive_portal_message)

    # Private

    def _load_next_url(self):
        if self._is_captive_portal_visible:
            self._browser_widget.clean_and_load(self._current_url)
            self._is_captive_portal_visible = False
            self._update_captive_portal_message()
        else:
            self._current_url = next(self._urls)
            self._browser_widget.clean_and_load(self._current_url)

    def _toggle_captive_portal(self):
        if self._is_captive_portal_visible:
            if self._connection.is_connected():
                self._captive_portal_message.setParent(None)
            self._browser_widget.clean_and_load(self._current_url)
        else:
            self._browser_widget.clean_and_load(QUrl(self._captive_portal_url))
        self._is_captive_portal_visible = not self._is_captive_portal_visible
        self._update_captive_portal_message()

    def _update_captive_portal_message(self):
        if self._is_captive_portal_visible:
            self._captive_portal_message.setCloseMessage(self._connection.is_connected())
        else:
            self._captive_portal_message.setOpenMessage()
