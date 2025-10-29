from PyQt6 import QtCore, QtWidgets, QtWebEngineWidgets, QtWebEngineCore, QtGui, QtSvgWidgets
from PyQt6.QtWebEngineCore import QWebEngineScript
from PyQt6.QtWebChannel import QWebChannel
from PyQt6.QtCore import pyqtSlot, Qt, QEvent
from PyQt6.QtGui import QKeyEvent
from PyQt6.QtWidgets import QApplication
from enum import Enum, auto
import logging
import re

from kiosk_browser import system, injected_scripts

# Config
reload_on_network_error_after = 5000 # ms

"""
Webview loading status
"""
class Status(Enum):
    LOADING = auto()
    NETWORK_ERROR = auto()
    LOADED = auto()


class FocusTransfer(QtCore.QObject):
    @staticmethod
    def _direction_to_event(direction) -> QKeyEvent | None:
        match direction:
            case "up":
                key = Qt.Key.Key_Up
            case "down":
                key = Qt.Key.Key_Down
            case _:
                key = None

        if key:
            return QKeyEvent(QEvent.Type.KeyPress, key,
                             Qt.KeyboardModifier.NoModifier, '', autorep=False)
        else:
            return None

    @pyqtSlot(str)
    def reached_end(self, direction):
        event = self._direction_to_event(direction)
        if event:
            # Expected to bubble up the widget stack and be handled by
            # MainWidget.keyPressEvent
            QApplication.instance().notify(self.parent(), event)


class BrowserWidget(QtWidgets.QWidget):
    def __init__(self, url, get_current_proxy, parent, keyboard_detector):
        QtWidgets.QWidget.__init__(self, parent)
        self.setStyleSheet(f"background-color: white;")

        self._url = url

        self._layout = QtWidgets.QHBoxLayout()
        self._layout.setContentsMargins(0, 0, 0, 0)
        self.setLayout(self._layout)

        self._focus_transfer = FocusTransfer(self)

        self._webchannel = QWebChannel()
        self._webchannel.registerObject("keyboard_detector", keyboard_detector)
        self._webchannel.registerObject("focus_transfer", self._focus_transfer)

        # Init views
        self._loading_page = loading_page(self)
        self._network_error_page = network_error_page(self)
        self._profile = QtWebEngineCore.QWebEngineProfile("Default")
        self._webview = QtWebEngineWidgets.QWebEngineView(self._profile, self)
        self._focus_shift_script = injected_scripts.FocusShiftScript()
        self._input_with_enter_script = injected_scripts.EnableInputToggleWithEnterScript()
        self._force_focused_element_highlight_script = injected_scripts.ForceFocusedElementHighlightingScript()
        self._keyboard_detector_bridge_script = injected_scripts.KeyboardDetectorBridge()

        # Add views to layout
        self._layout.addWidget(self._loading_page)
        self._layout.addWidget(self._network_error_page)
        self._layout.addWidget(self._webview)
        self._get_current_proxy = get_current_proxy

        # Register proxy authentication handler
        self._webview.page().proxyAuthenticationRequired.connect(self._proxy_auth)

        # Register QWebChannel
        self._webview.page().setWebChannel(self._webchannel)
        self._profile.scripts().insert(self._keyboard_detector_bridge_script)

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

        # Prepare reload timer
        self._reload_timer = QtCore.QTimer(self)
        self._reload_timer.setSingleShot(True)
        self._reload_timer.timeout.connect(self._webview.reload)

        # Load url
        self._webview.loadFinished.connect(self._load_finished)
        self.load(url)

    def _toggle_script_inject(self, script: QWebEngineScript, should_enable: bool):
        scripts = self._profile.scripts()
        if should_enable:
            if not scripts.contains(script):
                scripts.insert(script)
        else:
            scripts.remove(script)

    def reload(self):
        """ Show kiosk browser loading URL.
        """

        self._webview.setUrl(self._url)
        self._view(Status.LOADING)

        # If reload_timer is ongoing, stop it, as we’re already reloading
        if self._reload_timer.isActive():
            self._reload_timer.stop()

    def load(self, url: str, inject_spatial_navigation_scripts=False, inject_focus_highlight=False):
        """ Load specific URL, potentially injecting additional scripts into the page.
        """
        # inject_spatial_navigation_scripts toggle
        self._toggle_script_inject(self._focus_shift_script, inject_spatial_navigation_scripts)
        self._toggle_script_inject(self._input_with_enter_script, inject_spatial_navigation_scripts)

        # inject_focus_highlight toggle
        self._toggle_script_inject(self._force_focused_element_highlight_script, inject_focus_highlight)

        self._url = url
        self.reload()

    def hard_refresh(self):
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

    def closeEvent(self, event):
        # Unset page in web view to avoid it outliving the browser profile
        self._webview.setPage(None)
        return super().closeEvent(event)

    # Private

    def _load_finished(self, success):
        if success:
            self._view(Status.LOADED)
        if not success:
            self._view(Status.NETWORK_ERROR)
            self._reload_timer.start(reload_on_network_error_after)

    def _proxy_auth(self, url, auth, proxyHost):
        proxy = self._get_current_proxy()
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
