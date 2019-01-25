import sys
from itertools import cycle
from time import sleep

from PyQt5.QtCore import QUrl, pyqtSlot, Qt, QTimer
from PyQt5.QtGui import QKeySequence
from PyQt5.QtWidgets import QApplication, QShortcut
from PyQt5.QtWebEngineWidgets import QWebEngineView


class KioskBrowserWidget(QWebEngineView):
    def __init__(self, urls, toggle_sequence, *args, **kwargs):
        QWebEngineView.__init__(self, *args, **kwargs)

        self._urls = cycle(urls)
        self._openNextUrl()

        # Shortcut to cycle trough URLs
        self.shortcut = QShortcut(toggle_sequence, self)
        self.shortcut.activated.connect(self._openNextUrl)

        # Shortcut to manually reload
        self.reload_shortcut = QShortcut('CTRL+R', self)
        self.reload_shortcut.activated.connect(self.reload)

        # Check if pages is correctly loaded
        self.loadFinished.connect(self._loadFinished)

        # Shortcut to close
        self.quit_shortcut = QShortcut('CTRL+ALT+DELETE', self)
        self.quit_shortcut.activated.connect(lambda: self.close())

    @pyqtSlot()
    def _openNextUrl(self):
        self.load(next(self._urls))

    def _loadFinished(self, success):
        if not success:
            QTimer.singleShot(5000, self.reload)


class KioskBrowser:
    _urls = []
    _toggle_sequence = 'CTRL+TAB'
    _view = None

    def toggleKey(self, sequence):
        parsed_sequence = QKeySequence(sequence)
        self._toggle_sequence = parsed_sequence

    def addUrl(self, url):
        parsed_url = QUrl(url)
        if not parsed_url.isValid():
            raise InvalidUrl('Failed to parse URL "%s"' % url) from Exception
        self._urls.append(parsed_url)

    def open(self, fullscreen=True):
        if len(self._urls) == 0:
            raise NoUrl('No URLs defined') from Exception

        if len(self._urls) > 1 and self._toggle_sequence == '':
            raise NoToggleSequence(
                'Multiple URLs but no Toggle Key Sequence defined'
            ) from Exception

        self._app = QApplication(sys.argv)
        self._view = KioskBrowserWidget(
            urls=self._urls, toggle_sequence=self._toggle_sequence)
        self._view.setContextMenuPolicy(Qt.NoContextMenu)

        if fullscreen:
            self._fullscreen()

        self._app.exec()

    def _fullscreen(self):
        # Without a Window Manager, showFullScreen does not work under X,
        # so set the window size to the primary screen size.
        screen_size = self._app.primaryScreen().size()
        self._view.resize(screen_size)
        self._view.showFullScreen()
