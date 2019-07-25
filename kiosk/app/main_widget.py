from enum import Enum
from itertools import cycle
from PyQt5.QtCore import pyqtSlot, Qt, QUrl
from PyQt5.QtGui import QKeySequence
from PyQt5.QtWidgets import QWidget, QPushButton, QBoxLayout, QShortcut

from app.browser_widget import BrowserWidget

class MainWidget(QWidget):

    def __init__(self, urls, toggle_sequence):
        super(MainWidget, self).__init__()

        self._captive_portal_url = ''
        self._urls = cycle(urls)
        self._current_url = next(self._urls)
        self._browser_widget = BrowserWidget(self._current_url)
        self._is_captive_portal_visible = False
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
        if url == '' and not self._is_captive_portal_visible:
            self._button.setParent(None)
        else:
            self._update_button_text()
            self._layout.addWidget(self._button)

    # Private

    def _press_toggle(self):
        if self._is_captive_portal_visible:
            self._browser_widget.load(self._current_url)
            self._is_captive_portal_visible = False
            self._update_button_text()
        else:
            self._current_url = next(self._urls)
            self._browser_widget.load(self._current_url)

    def _press_button(self):
        if self._is_captive_portal_visible:
            self._browser_widget.load(self._current_url)
        else:
            self._browser_widget.load(QUrl(self._captive_portal_url))
        self._is_captive_portal_visible = not self._is_captive_portal_visible
        self._update_button_text()

    def _update_button_text(self):
        if self._is_captive_portal_visible:
            self._button.setText('Close captive portal')
        else:
            self._button.setText('Go to captive portal')
