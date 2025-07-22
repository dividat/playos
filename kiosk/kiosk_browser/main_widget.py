from PyQt6 import QtWidgets, QtCore, QtGui
import time
import logging
import importlib.resources
from PyQt6.QtQuickWidgets import QQuickWidget
from PyQt6.QtCore import QUrl, Qt, QEvent, QPoint
from PyQt6.QtWidgets import QApplication

from kiosk_browser import browser_widget, captive_portal, dialogable_widget, proxy as proxy_module

class KbdWidget(QQuickWidget):
    def visibleHeight(self):
        # Hack: hard-coded keyboardDesignHeight / keyboardDesignWidth values
        # from qtvirtualkeyboard's default/style.qml
        # Would be better to somehow read them from `QtQuick.VirtualKeyboard.Styles`
        return round(self.visibleWidth * 800 / 2560)

    def setVisibleWidth(self, width):
        self.visibleWidth = width

    # The QQuickWidget holding the virtual keyboard is sized explicitly w.r.t.
    # the parent widget/window and the positioning is handled by the parent
    # widget (see MainWidget._positionKbdWidget).
    #
    # An alternative approach would be to make the QQuickWidget take the size of
    # the whole window, enable transparency (see _make_transparent), make the
    # InputPanel a sub-element and move the positioning of the keyboard logic to
    # QML. However, this would prevent interaction with the page items
    # underneath the keyboard (until it is hidden) and might have other
    # unexpected consequences.
    def updateParentWidth(self, parentWidth):
        self.setVisibleWidth(parentWidth / 2)


    def _make_transparent(self):
        # A semi-hack to make the QQuickWidget have transparent background, see:
        # https://doc.qt.io/qt-6/qquickwidget.html#limitations
        self.setAttribute(Qt.WidgetAttribute.WA_AlwaysStackOnTop)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self.setClearColor(Qt.GlobalColor.transparent)

    def __init__(self):
        super(KbdWidget, self).__init__()

        input_panel_qml = importlib.resources.files('kiosk_browser').joinpath('inputpanel.qml')
        with importlib.resources.as_file(input_panel_qml) as f:
            logging.info(f"About to load widget from {f}")
            widget_qml = QUrl.fromLocalFile(str(f))
            self.setSource(widget_qml)
            if self.status() == QQuickWidget.Status.Error:
                raise RuntimeError(f"Failed to initialize inputpanel.qml: {self.errors()}")

        # needed for keyboardBackgroundNumeric to work, see inputpanel.qml
        self._make_transparent()

        self.setAttribute(Qt.WidgetAttribute.WA_AcceptTouchEvents)
        self.setFocusPolicy(Qt.FocusPolicy.NoFocus)

        self.visibleWidth = 0
        # The alternative ResizeMode.SizeViewToRootObject approach would be more
        self.setResizeMode(QQuickWidget.ResizeMode.SizeRootObjectToView);


class MainWidget(QtWidgets.QWidget):
    """ Show website from kiosk_url.

    - Show settings in a dialog using a shortcut or long pressing Menu.
    - Show toolbar message when captive portal is detected, opening it in a dialog.
    - Use proxy configured in Connman.
    """

    def __init__(self, kiosk_url: str, settings_url: str,
                 toggle_settings_key: str, fullscreen: bool):
        super(MainWidget, self).__init__()
        # Display
        self._primary_screen_con = None
        self._fullscreen = fullscreen

        # Proxy
        proxy = proxy_module.Proxy()
        proxy.start_monitoring_daemon()

        # Menu press
        self._menu_press_since = None
        self._menu_press_delay_seconds = 1.5

        # Browser widget
        self._kiosk_url = kiosk_url
        self._settings_url = settings_url
        self._dialogable_browser = dialogable_widget.DialogableWidget(
            parent = self,
            inner_widget = browser_widget.BrowserWidget(
                url = kiosk_url,
                get_current_proxy = proxy.get_current,
                parent = self),
            on_close = self._close_dialog)

        # Captive portal
        self._captive_portal_url = ''
        self._is_captive_portal_open = False
        self._captive_portal_message = captive_portal.OpenMessage(self._show_captive_portal, self)
        self._captive_portal = captive_portal.CaptivePortal(proxy.get_current, self._show_captive_portal_message)
        self._captive_portal.start_monitoring_daemon()

        # Layout
        self._layout = QtWidgets.QVBoxLayout()
        self._layout.setContentsMargins(0, 0, 0, 0)
        self._layout.setSpacing(0)
        self._layout.addWidget(self._captive_portal_message)
        self._layout.addWidget(self._dialogable_browser)
        self.setLayout(self._layout)


        self._kbdWidget = KbdWidget()
        self._kbdWidget.setParent(self)

        self._input_method = QApplication.inputMethod()

        # Note: The interleaving of cursorRectangleChanged and visibleChanged events
        # seems to depend on the input field focus sequence, so we simply respond to both
        self._input_method.cursorRectangleChanged.connect(self._positionKbdWidget)
        self._input_method.visibleChanged.connect(self._positionKbdWidget)
        self._positionKbdWidget()

        # Shortcuts
        QtGui.QShortcut(toggle_settings_key, self).activated.connect(self._toggle_settings)

        # Look at events with the eventFilter function
        self.installEventFilter(self)

    # Move the virtual keyboard to top or bottom of screen depending on where
    # the text input cursor is currently and resize the widget holding it.
    #
    # Note 1: Manually controlling the widget size with visibleWidth and
    # visibleHeight, because there are strange race conditions which lead to
    # _kbdWidget.width()/height() == 0.
    #
    # Note 2: cursorRectangle seems to be updated later than isVisible becomes
    # True, therefore the keyboard visibly jumps from bottom to the top. Some
    # form of debouncing could be used here to avoid it?
    def _positionKbdWidget(self):
        if not self._input_method.isVisible():
            self._kbdWidget.resize(QtCore.QSize(0, 0))
            return

        cursorTop = self._input_method.cursorRectangle().top()

        # Note: could also shift left/right using cursorRectangle().left() here
        kbdX = round((self.width() - self._kbdWidget.visibleWidth) / 2)

        if cursorTop > (self.height() / 2):
            # move to the top
            kbdY = 0
        else:
            # move to bottom
            kbdY = round(self.height() - self._kbdWidget.visibleHeight())

        self._kbdWidget.move(QPoint(kbdX, kbdY))
        self._kbdWidget.resize(QtCore.QSize(round(self._kbdWidget.visibleWidth), round(self._kbdWidget.visibleHeight())))


    def closeEvent(self, event):
        event.accept()

        # Unset page in web view to avoid it outliving the browser profile
        self._dialogable_browser.inner_widget()._webview.setPage(None)

    # Private

    def _toggle_settings(self):
        if self._dialogable_browser.is_decorated():
            self._close_dialog()
        else:
            self._dialogable_browser.inner_widget().load(self._settings_url)
            self._dialogable_browser.decorate("System Settings")

    def _show_captive_portal_message(self, url: str):
        self._captive_portal_url = QtCore.QUrl(url)
        if not self._captive_portal_message.is_open() and not self._is_captive_portal_open:
            self._captive_portal_message.show()

    def _show_captive_portal(self):
        self._close_dialog()
        self._captive_portal_message.hide()
        self._dialogable_browser.inner_widget().load(self._captive_portal_url)
        self._dialogable_browser.decorate("Network Login")
        self._is_captive_portal_open = True

    def _close_dialog(self):
        if self._dialogable_browser.is_decorated():
            self._dialogable_browser.undecorate()
            self._dialogable_browser.inner_widget().load(self._kiosk_url)
            if self._is_captive_portal_open:
                self._is_captive_portal_open = False

    def eventFilter(self, source, event):
        # Hide virtual keyboard with Escape or Back key
        # TODO: Play still receives the Escape key causing an exit from Play Settings
        if event.type() == QtCore.QEvent.Type.ShortcutOverride:
            if event.key() in [ QtCore.Qt.Key.Key_Escape, QtCore.Qt.Key.Key_Back ]:
                if self._input_method.isVisible():
                    self._input_method.hide()
                    # prevent further processing
                    event.accept()
                    return True

        # Toggle settings with a long press on the Menu key
        if event.type() == QtCore.QEvent.Type.ShortcutOverride:
            if event.key() == QtCore.Qt.Key.Key_Menu:
                if not event.isAutoRepeat():
                    self._menu_press_since = time.time()
                elif self._menu_press_since is not None and time.time() - self._menu_press_since > self._menu_press_delay_seconds:
                    self._menu_press_since = None
                    self._toggle_settings()
        elif event.type() == QtCore.QEvent.Type.KeyRelease:
            if event.key() == QtCore.Qt.Key.Key_Menu and not event.isAutoRepeat():
                self._menu_press_since = None

        return super(MainWidget, self).eventFilter(source, event)

    def handle_screen_change(self, new_primary):
        logging.info(f"Primary screen changed to {new_primary.name()}")
        if self._primary_screen_con is not None:
            QtCore.QObject.disconnect(self._primary_screen_con)

        self._primary_screen_con = \
            new_primary.geometryChanged.connect(self._resize_to_screen)

        # Precautionary sleep to allow Chromium to update screens
        time.sleep(1)
        self._resize_to_screen(new_primary.geometry())

    def resizeEvent(self, event):
        self._kbdWidget.updateParentWidth(event.size().width())
        self._positionKbdWidget()
        super().resizeEvent(event)

    def _resize_to_screen(self, new_geom):
        screen_size = new_geom.size()
        logging.info(f"Resizing widget based on new screen size: {screen_size}")
        if self._fullscreen:
            # Without a Window Manager, showFullScreen does not work under X,
            # so set the window size to the primary screen size.
            self.resize(screen_size)
            self.showFullScreen()
        else:
            self.resize(QtCore.QSize(round(screen_size.width() / 2), round(screen_size.height() / 2)))
            self.show()
