from PyQt6 import QtCore, QtWidgets, QtWebEngineWidgets, QtWebEngineCore, QtGui, QtSvgWidgets
from PyQt6.QtWidgets import QApplication
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
    LOADING = auto()
    NETWORK_ERROR = auto()
    LOADED = auto()

class BrowserWidget(QtWidgets.QWidget):

    def __init__(self, url, get_current_proxy, parent):
        QtWidgets.QWidget.__init__(self, parent)
        self.setStyleSheet(f"background-color: white;")

        self._url = url

        self._layout = QtWidgets.QHBoxLayout()
        self._layout.setContentsMargins(0, 0, 0, 0)
        self.setLayout(self._layout)

        # Init views
        self._loading_page = loading_page(self)
        self._network_error_page = network_error_page(self)
        self._profile = QtWebEngineCore.QWebEngineProfile("Default")
        self._webview = QtWebEngineWidgets.QWebEngineView(self._profile, self)

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
        self._webview.page().settings().setAttribute(QtWebEngineCore.QWebEngineSettings.WebAttribute.PlaybackRequiresUserGesture, False)

        # Prevent opening context menu on right click or pressing menu
        self._webview.setContextMenuPolicy(QtCore.Qt.ContextMenuPolicy.NoContextMenu)

        # Load url
        self._webview.setUrl(url)
        self._view(Status.LOADING)
        self._webview.loadFinished.connect(self._load_finished)
        self.setFocusProxy(self._webview)

        # Work-around to virtual keyboard input not working after idle time + window refocus.
        # Probably only needed for development, since PlayOS runs without a
        # window manager and so we don't expect window focus changes
        QApplication.instance().focusWindowChanged.connect(lambda _: self._restore_webview_focus())

        # Shortcut to manually reload
        QtGui.QShortcut('CTRL+R', self).activated.connect(self.reload)
        # Shortcut to perform a hard refresh
        QtGui.QShortcut('CTRL+SHIFT+R', self).activated.connect(self._hard_refresh)

        # Prepare reload timer
        self._reload_timer = QtCore.QTimer(self)
        self._reload_timer.setSingleShot(True)
        self._reload_timer.timeout.connect(self._webview.reload)

    def keyReleaseEvent(self, event):
        if event.key() == QtCore.Qt.Key.Key_Escape and QApplication.inputMethod().isVisible():
            QApplication.inputMethod().hide()
        else:
            super().keyReleaseEvent(event)

    def _restore_webview_focus(self):
        if self.isActiveWindow():
            self._webview.clearFocus()
            self._webview.setFocus()

    def reload(self):
        """ Show kiosk browser loading URL.
        """

        self._webview.setUrl(self._url)
        self._view(Status.LOADING)

        # If reload_timer is ongoing, stop it, as we’re already reloading
        if self._reload_timer.isActive():
            self._reload_timer.stop()

    def load(self, url: str):
        """ Load specific URL.
        """

        self._url = url
        self.reload()

    # Private

    def _load_finished(self, success):
        if success:
            self._view(Status.LOADED)
        if not success:
            self._view(Status.NETWORK_ERROR)
            self._reload_timer.start(reload_on_network_error_after)

    def _hard_refresh(self):
        """ Clear cache, then reload.

        Does not affect cookies or localstorage contents.

        NOTE This clears the entire HTTP cache, assumed to be OK as the kiosk targets a specific page.
        """
        logging.info(f"Clearing HTTP cache (hard refresh)")
        self._webview.page().profile().clearHttpCache()

        # Wait before triggering reload to avoid a possible race condition:
        # https://bugreports.qt.io/browse/QTBUG-111541
        # Version 6.7 of Qt will provide a signal once the cache has been cleared:
        # https://doc.qt.io/qt-6/qwebengineprofile.html#clearHttpCacheCompleted
        self._view(Status.LOADING)
        self._reload_timer.start(250)

    def _proxy_auth(self, get_current_proxy, url, auth, proxyHost):
        proxy = get_current_proxy()
        if proxy is not None and proxy.credentials is not None:
            logging.info("Authenticating proxy")
            auth.setUser(proxy.credentials.username)
            auth.setPassword(proxy.credentials.password)
        else:
            logging.info("Proxy authentication request ignored because credentials are not provided.")

    def _view(self, status):
        if status == Status.LOADING:
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
            # focus is lost after using CTRL+R
            self._restore_webview_focus()

def user_agent_with_system(user_agent, system_name, system_version):
    """Inject a specific system into a user agent string"""
    pattern = re.compile(r'(Mozilla/5.0) \(([^\)]*)\)(.*)')
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

    movie = QtGui.QMovie("images/spinner.gif")
    movie.start()

    label = QtWidgets.QLabel(parent)
    label.setMovie(movie)

    return hcenter(label, parent)

def network_error_page(parent):
    """ Show network error page.
    """

    icon = QtWidgets.QLabel(parent)
    icon.setPixmap(QtGui.QPixmap("images/no-internet-icon.png")) # https://flaticons.net

    title = QtWidgets.QLabel("No Internet Connection", parent)
    title.setStyleSheet("""
        font-size: 45px;
        font-weight: bold;
    """)

    paragraph_1 = paragraph("Please ensure the Internet connection to this device is active.", parent)
    paragraph_2 = paragraph("If the problem persists, contact Senso Service.", parent)

    logo = QtSvgWidgets.QSvgWidget("images/dividat-logo.svg", parent)
    logo.renderer().setAspectRatioMode(QtCore.Qt.AspectRatioMode.KeepAspectRatio)
    logo.setFixedHeight(30)

    layout = QtWidgets.QVBoxLayout()
    layout.addStretch(1)
    layout.addWidget(hcenter(icon, parent))
    layout.addSpacing(30)
    layout.addWidget(hcenter(title, parent))
    layout.addSpacing(20)
    layout.addWidget(hcenter(paragraph_1, parent))
    layout.addWidget(hcenter(paragraph_2, parent))
    layout.addStretch(1)
    layout.addWidget(hcenter(logo, parent))
    layout.addSpacing(20)

    widget = QtWidgets.QWidget()
    widget.setLayout(layout)

    return widget

def paragraph(text, parent):
    label = QtWidgets.QLabel(text, parent)
    label.setStyleSheet("font-size: 20px;")
    return label

def hcenter(child, parent):
    """ Center widget horizontally inside another widget.
    """

    layout = QtWidgets.QHBoxLayout()
    layout.addStretch(1)
    layout.addWidget(child)
    layout.addStretch(1)

    widget = QtWidgets.QWidget(parent)
    widget.setLayout(layout)

    return widget
