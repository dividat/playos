from PyQt5 import QtCore, QtWidgets, QtWebEngineWidgets
from enum import Enum, auto
import logging
import re

from kiosk_browser import system

# Config
reload_on_network_error_after = 5000 # ms

"""
Webview loading status
"""
class Status(Enum):
    INITIAL_LOADING = auto()
    NETWORK_ERROR = auto()
    LOADED = auto()

class BrowserWidget(QtWidgets.QWidget):

    def __init__(self, url, get_current_proxy, parent):
        QtWidgets.QWidget.__init__(self, parent)

        self._url = url

        self._layout = QtWidgets.QHBoxLayout()
        self._layout.setContentsMargins(0, 0, 0, 0)
        self.setLayout(self._layout)

        # Init views
        self._loading_page = loading_page(self)
        self._network_error_page = network_error_page(self)
        self._webview = QtWebEngineWidgets.QWebEngineView(self)

        # Add views to layout
        self._layout.addWidget(self._loading_page)
        self._layout.addWidget(self._network_error_page)
        self._layout.addWidget(self._webview)

        # Register proxy authentication handler
        self._webview.page().proxyAuthenticationRequired.connect(
            lambda url, auth, proxyHost: self._proxy_auth(
                get_current_proxy, url, auth, proxyHost))

        # Override user agent
        self._webview.page().profile().setHttpUserAgent(user_agent_with_system(
            user_agent = self._webview.page().profile().httpUserAgent(),
            system_name = system.NAME,
            system_version = system.VERSION
        ))

        # Allow sound playback without user gesture
        self._webview.page().settings().setAttribute(QtWebEngineWidgets.QWebEngineSettings.PlaybackRequiresUserGesture, False)

        # Load url
        self._webview.setUrl(url)
        self._view(Status.INITIAL_LOADING)
        self._webview.loadFinished.connect(self._load_finished)

        # Stretch the view
        policy = QtWidgets.QSizePolicy()
        policy.setVerticalStretch(1)
        policy.setHorizontalStretch(1)
        policy.setVerticalPolicy(QtWidgets.QSizePolicy.Preferred)
        policy.setHorizontalPolicy(QtWidgets.QSizePolicy.Preferred)
        self.setSizePolicy(policy)

        # Shortcut to manually reload
        self.reload_shortcut = QtWidgets.QShortcut('CTRL+R', self)
        self.reload_shortcut.activated.connect(self.reload)

        # Prepare reload timer
        self._reload_timer = QtCore.QTimer(self)
        self._reload_timer.setSingleShot(True)
        self._reload_timer.timeout.connect(self._webview.reload)

    def show_blank_page(self):
        """ Hide browser widget by showing a blank page.
        """
        self._webview.setHtml("")

    def reload(self):
        """ Show kiosk browser loading URL.
        """

        self._webview.setUrl(self._url)
        self._view(Status.INITIAL_LOADING)

        # Stop reload timer if it is on going
        if self._reload_timer.isActive():
            self._reload_timer.stop()

    # Private

    def _load_finished(self, success):
        if success:
            self._view(Status.LOADED)
        if not success:
            self._view(Status.NETWORK_ERROR)
            self._reload_timer.start(reload_on_network_error_after)

    def _proxy_auth(self, get_current_proxy, url, auth, proxyHost):
        proxy = get_current_proxy()
        if proxy is not None and proxy.username is not None and proxy.password is not None:
            logging.info("Authenticating proxy")
            auth.setUser(proxy.username)
            auth.setPassword(proxy.password)
        else:
            logging.info("Proxy authentication request ignored because credentials are not provided.")

    def _view(self, status):
        if status == Status.INITIAL_LOADING:
            self._loading_page.show()
            self._network_error_page.hide()
            self._webview.hide()
        elif status == Status.NETWORK_ERROR:
            self._loading_page.hide()
            self._network_error_page.show()
            self._webview.hide()
        elif status == Status.LOADED:
            self._loading_page.hide()
            self._network_error_page.hide()
            self._webview.show()

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

def loading_page(parent):
    """ Show a loader in the middle of a blank page.
    """

    widget = QtWidgets.QLabel("Loading…", parent)
    return widget

def network_error_page(parent):
    """ Show network error message.
    """

    widget = QtWidgets.QLabel("Network error, sorry…", parent)
    return widget
