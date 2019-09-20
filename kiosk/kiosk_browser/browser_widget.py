import re
from PyQt5.QtCore import QTimer
from PyQt5.QtWidgets import QShortcut
from PyQt5.QtWebEngineWidgets import QWebEngineView, QWebEnginePage, QWebEngineProfile
from PyQt5.QtWidgets import QSizePolicy

class BrowserWidget(QWebEngineView):

    def __init__(self, system_name, system_version, url, *args, **kwargs):
        QWebEngineView.__init__(self, *args, **kwargs)

        self._profile = get_profile(system_name, system_version)
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

        # Recreate a new page in order to clear the screen the moment the
        # shortcut is pressed
        page = QWebEnginePage(self._profile)

        page.setUrl(url)
        self.setPage(page)

    def _load_finished(self, success):
        if not success:
            QTimer.singleShot(5000, self.reload)

def get_profile(system_name, system_version):
    profile = QWebEngineProfile.defaultProfile()
    profile.setHttpUserAgent(user_agent_with_system(
        user_agent = profile.httpUserAgent(),
        system_name = system_name,
        system_version = system_version
    ))
    return profile

def user_agent_with_system(user_agent, system_name, system_version):
    """Inject a specific system into a user agent string"""
    pattern = re.compile('(Mozilla/5.0) \(([^\)]*)\)(.*)')
    m = pattern.match(user_agent)

    if m == None:
        return f"{system_name}/{system_version} {user_agent}"
    else:
        if not m.group(2):
            system_detail = f"{system_name} {system_version}"
        else:
            system_detail = f"{m.group(2)}; {system_name} {system_version}"

        return f"{m.group(1)} ({system_detail}){m.group(3)}"
