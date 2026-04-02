from PyQt6 import QtCore, QtWidgets, QtWebEngineWidgets, QtWebEngineCore, QtGui, QtSvgWidgets
from PyQt6.QtWebEngineCore import QWebEngineScript, QWebEnginePage, QWebEngineLoadingInfo
from PyQt6.QtWebChannel import QWebChannel
from PyQt6.QtCore import pyqtSlot, pyqtSignal, Qt, QEvent, QUrl
from PyQt6.QtGui import QKeyEvent
from PyQt6.QtWidgets import QApplication
from enum import Enum, auto
import logging
import re
import math

from kiosk_browser import system, injected_scripts
from kiosk_browser.ui import DarkButton

# Config
reload_on_network_error_after = 5000 # ms

"""
Webview loading status
"""
class Status(Enum):
    LOADING = auto()
    NETWORK_ERROR = auto()
    LOADED = auto()


class TimerWithTicks(QtCore.QObject):
    """A timer that behaves like a regular QTimer, but can also emit
    signals at regular intervals before timeout.

    Allows to implement "3... 2... 1... TIMEOUT" style countdowns.

    Signals:
        tick(int): Emitted every tickInterval with remaining time count
        timeout: Emitted after ticks * tickInterval (inherited from QTimer)

    Examples:
        timer.start(1000, 3) will:
            - at t = 0    will emit tick(3000)
            - at t = 1000 will emit tick(2000)
            - at t = 2000 will emit tick(1000)
            - at t = 3000 will emit timeout

        timer.start(x, 1) will emit a timeout the same as QTimer.start(x)
    """
    tick = pyqtSignal(int)
    timeout = pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._internalTimer = QtCore.QTimer()
        self._internalTimer.setSingleShot(False)
        self._internalTimer.timeout.connect(self._on_internal_timeout)
        self._tickInterval = 0
        self._remainingTicks = 0


    def start(self, tickIntervalMs: int, ticks: int = 1):
        self._tickInterval = tickIntervalMs
        self._remainingTicks = ticks
        self._on_internal_timeout()
        self._internalTimer.setInterval(tickIntervalMs)
        self._internalTimer.start()

    def stop(self):
        return self._internalTimer.stop()

    def isActive(self):
        return self._internalTimer.isActive()

    def _on_internal_timeout(self):
        if self._remainingTicks <= 0:
            self.stop()
            self.timeout.emit()
        else:
            self.tick.emit(self.remainingTime())
        self._remainingTicks -= 1

    def remainingTime(self):
        return self._remainingTicks * self._tickInterval


class NetworkErrorRetryWidget(QtWidgets.QWidget):
    """This widget is used when a network error occurs, it:
        1. Manages the reload_timer while retrying
        2. Displays a reload countdown and spinner
        3. Displays the last network error details
    """

    def __init__(self, reload_timer: TimerWithTicks, parent=None):
        self._tick_interval_ms = 200
        # To avoid a "flicker" effect when the network error is nearly
        # instantenous (<300ms), we show the spinner slightly earlier
        self._prestart_spinner_time_ms = 400

        super().__init__(parent)
        self._reload_timer = reload_timer

        self._retry_countdown_label = QtWidgets.QLabel(self)
        self._loading_spinner = loading_spinner()
        self._error_reason_label = QtWidgets.QLabel(self)
        # for style-sheet
        self._error_reason_label.setObjectName("error_reason")

        self._countdown_or_spinner = QtWidgets.QStackedWidget(self)
        self._countdown_or_spinner.addWidget(self._retry_countdown_label)
        self._countdown_or_spinner.addWidget(self._loading_spinner)

        self._layout = QtWidgets.QVBoxLayout()
        self._layout.addWidget(hcenter(self._countdown_or_spinner))
        self._layout.addWidget(hcenter(self._error_reason_label))
        self.setLayout(self._layout)

        self._reload_timer.tick.connect(self._update_countdown)

    def start_reload(self):
        return self._reload_timer.start(
            self._tick_interval_ms,
            (reload_on_network_error_after + self._prestart_spinner_time_ms) // self._tick_interval_ms
        )

    def _update_countdown(self, remaining_time: int):
        if remaining_time <= self._prestart_spinner_time_ms:
            self._countdown_or_spinner.setCurrentWidget(self._loading_spinner)
        else:
            display_remaining_time = remaining_time - self._prestart_spinner_time_ms
            self._retry_countdown_label.setText(f"Retrying in { math.ceil(display_remaining_time/1000.0) } seconds…")


    def _loading_changed(self, loading_info):
        error_text = format_loading_error(loading_info)

        match loading_info.status():
            case QWebEngineLoadingInfo.LoadStatus.LoadStartedStatus:
                # Do nothing to preserve the error reason
                pass

            case QWebEngineLoadingInfo.LoadStatus.LoadFailedStatus:
                page_url = loading_info.url().toString()
                logging.warning(f"Page '{page_url}' load failed: {error_text}")
                self._error_reason_label.setText(f"Technical details: {error_text}")
                self._countdown_or_spinner.setCurrentWidget(self._retry_countdown_label)

            case QWebEngineLoadingInfo.LoadStatus.LoadStoppedStatus:
                # this should not happen, since we do not expect any (manual or
                # automatic) load interrupts
                self._error_reason_label.setText(f"Loading stopped unexpectedly: {error_text}")
                self._countdown_or_spinner.setCurrentWidget(self._retry_countdown_label)

            case QWebEngineLoadingInfo.LoadStatus.LoadSucceededStatus:
                self._error_reason_label.setText("")


# Small helper class for handling focus-shift:exhausted events, used to
# "transfer" focus out of the page (QWebEngineView) into other widgets.
#
# It works by translating the exhausted direction "back" to a KeyPress event.
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


# Expose the ability to "fully" reload the page from Play
class ReloadHandler(QtCore.QObject):
    @pyqtSlot(str)
    def before_reload(self, url):
        self.parent().full_reload(url=url)


class BrowserWidget(QtWidgets.QWidget):
    def __init__(self, url, get_current_proxy, parent, max_cache_size, keyboard_detector, request_network_settings):
        QtWidgets.QWidget.__init__(self, parent)
        self.setStyleSheet(f"background-color: white;")

        self._url = url
        self._is_full_reload = False

        self._layout = QtWidgets.QHBoxLayout()
        self._layout.setContentsMargins(0, 0, 0, 0)
        self.setLayout(self._layout)

        self._focus_transfer = FocusTransfer(self)
        self._reload_handler = ReloadHandler(self)

        self._webchannel = QWebChannel()
        self._webchannel.registerObject("keyboard_detector", keyboard_detector)
        self._webchannel.registerObject("focus_transfer", self._focus_transfer)
        self._webchannel.registerObject("reload_handler", self._reload_handler)

        self._reload_timer = TimerWithTicks(self)

        # Init views
        self._loading_page = loading_spinner()
        self._network_error_retry_widget = NetworkErrorRetryWidget(
            self._reload_timer, parent=self)
        self._network_error_page = network_error_page(
            self._network_error_retry_widget,
            request_network_settings)

        self._profile = QtWebEngineCore.QWebEngineProfile("Default")
        self._profile.setHttpCacheMaximumSize(max_cache_size)
        self._webview = QtWebEngineWidgets.QWebEngineView(self._profile, self)
        self._focus_shift_script = injected_scripts.FocusShiftScript()
        self._input_with_enter_script = injected_scripts.EnableInputToggleWithEnterScript()
        self._force_focused_element_highlight_script = injected_scripts.ForceFocusedElementHighlightingScript()
        self._play_bridge_script = injected_scripts.PlayBridge()

        # Handle page (renderer) kills
        self._webview.renderProcessTerminated.connect(self._handle_render_process_terminated)

        # Add views to layout
        self._layout.addWidget(self._loading_page)
        self._layout.addWidget(self._network_error_page)
        self._layout.addWidget(self._webview)
        self._get_current_proxy = get_current_proxy

        # Register proxy authentication handler
        self._webview.page().proxyAuthenticationRequired.connect(self._proxy_auth)

        # Register QWebChannel
        assert self._play_bridge_script.worldId() == self._focus_shift_script.worldId(), \
            "FocusShiftScript and PlayBridge must have the same worldId!"
        self._webview.page().setWebChannel(self._webchannel,
                                           self._play_bridge_script.worldId())
        self._profile.scripts().insert(self._play_bridge_script)

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

        self._reload_timer.timeout.connect(self._webview.reload)

        # Load url
        self._webview.loadFinished.connect(self._load_finished)
        self._webview.page().loadingChanged.connect(self._network_error_retry_widget._loading_changed)
        self.load(url)

    def _handle_render_process_terminated(self, termination_status, exit_code):
        is_normal_termination = termination_status == QWebEnginePage.RenderProcessTerminationStatus.NormalTerminationStatus
        is_ok_exit = exit_code == 0
        if is_normal_termination and is_ok_exit:
            return
        else:
            logging.error(f"QtWebEngine Renderer process exited abnormaly ({termination_status=} {exit_code=}), stopping application")
            self.deleteLater() # avoids segfault
            QApplication.exit(1)


    def _toggle_script_inject(self, script: QWebEngineScript, should_enable: bool):
        scripts = self._profile.scripts()
        if should_enable:
            if not scripts.contains(script):
                scripts.insert(script)
        else:
            scripts.remove(script)

    # Perform a "full" reload, loading a new URL if specified.
    #
    # Note: this assumes script injection rules are not changing, i.e.
    # we remain in the same dialog (cf. `BrowserWidget.load(..)`)
    def full_reload(self, url=""):
        # Temporarily navigate to an empty page
        self._webview.setUrl(QUrl("about:none"))

        # Trigger webview reload only when load finishes - calling
        # self._webview.reload() here directly would reset the URL
        # (strange QWebEngineView behaviour/bug)
        self._is_full_reload = True

        if url:
            url = QUrl(url)

        # Load the new URL or restore the original one.
        self.reload(url=url)

    def reload(self, url=None):
        """ Show kiosk browser loading URL.
        """
        if not url:
            url = self._url

        self._webview.setUrl(url)
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
        # Trigger an explicit reload, see BrowserWidget.full_reload(..)
        if self._is_full_reload:
            self._is_full_reload = False
            self._webview.reload()
            return

        if success:
            self._view(Status.LOADED)
        if not success:
            self._view(Status.NETWORK_ERROR)
            self._network_error_retry_widget.start_reload()


    def _proxy_auth(self, url, auth, proxyHost):
        proxy = self._get_current_proxy()
        if proxy is not None and proxy.credentials is not None:
            logging.info("Authenticating proxy")
            auth.setUser(proxy.credentials.username)
            auth.setPassword(proxy.credentials.password)
        else:
            logging.info("Proxy authentication request ignored because credentials are not provided.")

    def _view(self, status):
        views = [ self._loading_page, self._network_error_page, self._webview ]

        active_view = None
        match status:
            case Status.LOADING:
                active_view = self._loading_page
            case Status.NETWORK_ERROR:
                active_view = self._network_error_page
            case Status.LOADED:
                active_view = self._webview

        for view in views:
            if view == active_view:
                view.show()
                self.setFocusProxy(view)
                view.clearFocus()
                view.setFocus()
            else:
                view.hide()

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

def loading_spinner():
    """ Show a loader centered in the middle
    """

    movie = QtGui.QMovie("images/spinner.gif")
    movie.start()

    label = QtWidgets.QLabel()
    label.setMovie(movie)
    # ensure label fits the QMovie exactly
    label.setSizePolicy(QtWidgets.QSizePolicy.Policy.Fixed,
                        QtWidgets.QSizePolicy.Policy.Fixed)

    return hcenter(label)


def network_error_page(network_error_retry_widget: NetworkErrorRetryWidget, request_network_settings):
    """ Show network error page.
    """

    widget = QtWidgets.QWidget()

    icon = QtWidgets.QLabel()
    icon.setPixmap(QtGui.QPixmap("images/no-internet-icon.png")) # https://flaticons.net

    title = QtWidgets.QLabel("No Internet Connection")
    title.setStyleSheet("""
        font-size: 45px;
        font-weight: bold;
    """)

    button = DarkButton('Open Network settings', widget)
    button.setFixedHeight(40)
    font = button.font()
    font.setPointSize(16)
    button.setFont(font)
    button.clicked.connect(request_network_settings)
    button.setDefault(True)

    main_block = [
        paragraph("Please ensure the device has an active Internet connection"
                  " and is not blocked by a firewall."),
        paragraph("To configure the connection, go to Network settings:"),
        button,
    ]

    network_error_retry_widget.setStyleSheet("""
        * {
            font-size: 16px; color: #666;
        }
        #error_reason {
            font-size: 12px;
        }
    """)

    logo = QtSvgWidgets.QSvgWidget("images/dividat-logo.svg")
    logo.renderer().setAspectRatioMode(QtCore.Qt.AspectRatioMode.KeepAspectRatio)
    logo.setFixedHeight(30)

    layout = QtWidgets.QVBoxLayout()
    layout.addStretch(1)
    layout.addWidget(hcenter(icon))
    layout.addSpacing(30)
    layout.addWidget(hcenter(title))
    layout.addSpacing(20)
    for w in main_block:
        layout.addWidget(hcenter(w))
    layout.addWidget(hcenter(network_error_retry_widget))
    layout.addStretch(1)
    layout.addWidget(hcenter(logo))
    layout.addSpacing(20)

    widget.setLayout(layout)
    widget.setFocusProxy(button)

    return widget

def paragraph(text):
    label = QtWidgets.QLabel(text)
    label.setStyleSheet("font-size: 20px;")
    return label

def hcenter(child):
    """ Center widget horizontally inside another widget.
    """

    layout = QtWidgets.QHBoxLayout()
    layout.addStretch(1)
    layout.addWidget(child)
    layout.addStretch(1)

    widget = QtWidgets.QWidget()
    widget.setLayout(layout)

    return widget


def format_loading_error(loading_info: QWebEngineLoadingInfo) -> str:
    error_details = f"code: {loading_info.errorCode()}, reason: {loading_info.errorString()}"

    error_reason = ""
    match loading_info.errorDomain():
        case QWebEngineLoadingInfo.ErrorDomain.DnsErrorDomain:
            error_reason = "DNS error"
        case QWebEngineLoadingInfo.ErrorDomain.HttpStatusCodeDomain:
            error_reason = "HTTP status error"
        case QWebEngineLoadingInfo.ErrorDomain.CertificateErrorDomain:
            error_reason = "SSL Certificate error"
        case QWebEngineLoadingInfo.ErrorDomain.ConnectionErrorDomain:
            error_reason = "Connection error"
        case QWebEngineLoadingInfo.ErrorDomain.HttpErrorDomain:
            error_reason = "HTTP connection error"
        case _:
            error_reason = f"Unknown error ({loading_info.errorDomain()})"

    return f"{error_reason}, {error_details}"
