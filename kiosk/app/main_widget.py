from enum import Enum
from PyQt5.QtCore import pyqtSlot, Qt, QUrl
from PyQt5.QtGui import QKeySequence
from PyQt5.QtWidgets import QWidget, QPushButton, QBoxLayout, QShortcut

from app.browser_widget import BrowserWidget

class View(Enum):
    PLAY = 1
    SETTINGS = 2
    PORTAL = 3

class MainWidget(QWidget):

    def __init__(self, play_url, settings_url, toggle_sequence):
        super(MainWidget, self).__init__()

        self._captive_portal_url = ''
        self._view = View.PLAY
        self._play_url = play_url
        self._settings_url = settings_url
        self._browser_widget = BrowserWidget(play_url)
        self._layout = QBoxLayout(QBoxLayout.Direction.Up)
        self._button = QPushButton()
        self._button.setFlat(True)
        self._button.clicked.connect(self._press_button)

        QShortcut(toggle_sequence, self).activated.connect(self._press_toggle)

        self._layout.setContentsMargins(0, 0, 0, 0)
        self._layout.setSpacing(0)
        self._layout.addWidget(self._browser_widget)

        self.setLayout(self._layout)

        self.show()

    def set_captive_portal_url(self, url):
        self._captive_portal_url = url
        self._show_or_hide_captive_portal_button()

    # Private

    def _press_toggle(self):
        if self._view == View.PLAY:
            self._browser_widget.load(self._settings_url)
            self._view = View.SETTINGS
        else:
            self._browser_widget.load(self._play_url)
            self._view = View.PLAY
        self._show_or_hide_captive_portal_button()

    def _show_or_hide_captive_portal_button(self):
        if self._view == View.PLAY or self._captive_portal_url == '' and self._view != View.PORTAL:
            self._button.setParent(None)
        else:
            self._update_button_text()
            self._layout.addWidget(self._button)

    def _update_button_text(self):
        if self._view == View.SETTINGS:
            self._button.setText('Go to captive portal')
        elif self._view == View.PORTAL:
            self._button.setText('Back to settings')

    def _press_button(self):
        if self._view == View.SETTINGS:
            self._browser_widget.load(QUrl(self._captive_portal_url))
            self._view = View.PORTAL
            self._update_button_text()
        else:
            self._browser_widget.load(self._settings_url)
            self._view = View.SETTINGS
            self._button.setParent(None)
