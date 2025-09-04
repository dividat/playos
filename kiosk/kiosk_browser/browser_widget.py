from PyQt6 import QtCore, QtWidgets, QtWebEngineWidgets, QtWebEngineCore, QtGui, QtSvgWidgets
from PyQt6.QtWebEngineCore import QWebEngineScript
from PyQt6.QtWidgets import QApplication
from enum import Enum, auto
import logging
import re

from kiosk_browser import system, assets

# Config
reload_on_network_error_after = 5000 # ms

"""
Webview loading status
"""
class Status(Enum):
    LOADING = auto()
    NETWORK_ERROR = auto()
    LOADED = auto()


# base class for setup
class KioskInjectedScript(QWebEngineScript):
    def __init__(self, name):
        super().__init__()
        self.setName(name)
        self.setInjectionPoint(QWebEngineScript.InjectionPoint.DocumentReady)
        self.setRunsOnSubFrames(True) # TODO: ?
        self.setWorldId(QWebEngineScript.ScriptWorldId.ApplicationWorld)

class FocusShiftScript(KioskInjectedScript):
    def __init__(self):
        super().__init__("focusShift")
        self.setSourceUrl(QtCore.QUrl.fromLocalFile(assets.FOCUS_SHIFT_PATH))

class EnableInputToggleWithEnterScript(KioskInjectedScript):
    def __init__(self):
        super().__init__("inputToggleWithEnter")
        self.setSourceCode("""
// simplified version of SpatialNavigation.ts in diviapps
document.addEventListener('keydown', (event) => {
    if (event.key === 'Enter') {
        performSyntheticClick(event)
    }
})
function performSyntheticClick(event) {
    const activeElement = document.activeElement
    if (
        activeElement instanceof HTMLInputElement &&
        (activeElement.type === 'checkbox' || activeElement.type === 'radio')
    ) {
        activeElement.click()
        event.preventDefault()
    }
}
        """)


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
        self._focus_shift_script = FocusShiftScript()
        self._input_with_enter_script = EnableInputToggleWithEnterScript()
        # enabled on all pages!
        self._profile.scripts().insert(self._input_with_enter_script)

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

        self.setFocusProxy(self._webview)

        # Shortcut to manually reload
        QtGui.QShortcut('CTRL+R', self).activated.connect(self.reload)
        # Shortcut to perform a hard refresh
        QtGui.QShortcut('CTRL+SHIFT+R', self).activated.connect(self._hard_refresh)

        # Prepare reload timer
        self._reload_timer = QtCore.QTimer(self)
        self._reload_timer.setSingleShot(True)
        self._reload_timer.timeout.connect(self._webview.reload)

        # Load url
        self._webview.loadFinished.connect(self._load_finished)
        self.load(url)

    def _toggle_focus_shift_inject(self, should_enable: bool):
        if should_enable and not self._profile.scripts().contains(self._focus_shift_script):
            self._profile.scripts().insert(self._focus_shift_script)
        else:
            self._profile.scripts().remove(self._focus_shift_script)

    def reload(self):
        """ Show kiosk browser loading URL.
        """

        self._webview.setUrl(self._url)
        self._view(Status.LOADING)

        # If reload_timer is ongoing, stop it, as we’re already reloading
        if self._reload_timer.isActive():
            self._reload_timer.stop()

    def load(self, url: str, inject_focus_shift=False):
        """ Load specific URL.
        """
        self._toggle_focus_shift_inject(inject_focus_shift)

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
            # Set focus by clearing first, otherwise focus is lost after using CTRL+R
            self._webview.clearFocus()
            self._webview.setFocus()

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
