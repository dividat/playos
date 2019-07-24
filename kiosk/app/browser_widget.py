from PyQt5.QtCore import QTimer
from PyQt5.QtWidgets import QShortcut
from PyQt5.QtWebEngineWidgets import QWebEngineView

class BrowserWidget(QWebEngineView):
    def __init__(self, url, *args, **kwargs):
        QWebEngineView.__init__(self, *args, **kwargs)

        self.load(url)

        # Shortcut to manually reload
        self.reload_shortcut = QShortcut('CTRL+R', self)
        self.reload_shortcut.activated.connect(self.reload)

        # Check if pages is correctly loaded
        self.loadFinished.connect(self._loadFinished)

        # Shortcut to close
        self.quit_shortcut = QShortcut('CTRL+ALT+DELETE', self)
        self.quit_shortcut.activated.connect(lambda: self.close())

    def _loadFinished(self, success):
        if not success:
            QTimer.singleShot(5000, self.reload)
