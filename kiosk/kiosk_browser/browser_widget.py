from PyQt5.QtCore import QTimer
from PyQt5.QtWidgets import QShortcut
from PyQt5.QtWebEngineWidgets import QWebEngineView, QWebEnginePage, QWebEngineProfile
from PyQt5.QtWidgets import QSizePolicy

class BrowserWidget(QWebEngineView):

    def __init__(self, name, url, *args, **kwargs):
        QWebEngineView.__init__(self, *args, **kwargs)

        profile = QWebEngineProfile.defaultProfile()
        profile.setHttpUserAgent(f"{name} {profile.httpUserAgent()}")
        self._page = QWebEnginePage(profile)
        self.setPage(self._page)

        self.clean_and_load(url)

        # Shortcut to manually reload
        self.reload_shortcut = QShortcut('CTRL+R', self)
        self.reload_shortcut.activated.connect(self.reload)

        # Check if pages is correctly loaded
        self.loadFinished.connect(self._load_finished)

        # Shortcut to close
        self.quit_shortcut = QShortcut('CTRL+ALT+DELETE', self)
        self.quit_shortcut.activated.connect(lambda: self.close())

        # Stretch the browser
        policy = QSizePolicy()
        policy.setVerticalStretch(1)
        policy.setHorizontalStretch(1)
        policy.setVerticalPolicy(QSizePolicy.Preferred)
        policy.setHorizontalPolicy(QSizePolicy.Preferred)
        self.setSizePolicy(policy)

    def clean_and_load(self, url):
        self._page.setHtml("")
        self._page.load(url)

    def _load_finished(self, success):
        if not success:
            QTimer.singleShot(5000, self.reload)
