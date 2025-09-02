import importlib.resources
from PyQt6 import QtCore, sip
from PyQt6.QtCore import QUrl, Qt, QPoint, QSize
from PyQt6.QtQuickWidgets import QQuickWidget
from PyQt6.QtWidgets import QApplication
import json
import logging
import os

PLAYOS_LANGUAGES_CONFIG = "/etc/playos/languages.json"
# for easier testing, semicolon separated, e.g. de_DE;fr_FR
PLAYOS_LANGUAGES_EXTRA = os.getenv("PLAYOS_LANGUAGES_EXTRA", "")

# Prevent Escape key from reaching focus object when virtual keyboard is
# activated and instead hide the virtual keyboard.
# Both KeyPress and the following KeyRelease are handled.
class EscapeKeyFilter(QtCore.QObject):
    def __init__(self, parent):
        super().__init__(parent)

        self._focus_object = None
        self._last_keypress_closed_vkb = False

        QApplication.instance().focusObjectChanged.connect(self._update_focus_object)

    def _update_focus_object(self, new_focus_object):
        if self._focus_object is not None:
            # prevent crashes when underlying C++ object gets destroyed, but we
            # are still holding onto the reference
            if not sip.isdeleted(self._focus_object):
                self._focus_object.removeEventFilter(self)

        # Workaround to QTBUG-138256, see also patch in pkgs/qtvirtualkeyboard/
        if new_focus_object != QApplication.focusObject():
            new_focus_object = QApplication.focusObject()

        if new_focus_object is None:
            return

        new_focus_object.installEventFilter(self)

        self._focus_object = new_focus_object


    def eventFilter(self, source, event):
        if event.type() == QtCore.QEvent.Type.KeyPress:
            self._last_keypress_closed_vkb = False

            if event.key() == QtCore.Qt.Key.Key_Escape:
                if QApplication.inputMethod().isVisible():
                    QApplication.inputMethod().hide()
                    self._last_keypress_closed_vkb = True
                    return True

        elif event.type() == QtCore.QEvent.Type.KeyRelease:
            # stop KeyRelease propagation too if we just closed the keyboard
            if event.key() == QtCore.Qt.Key.Key_Escape and self._last_keypress_closed_vkb:
                    return True

        return False

class KeyboardWidget(QQuickWidget):
    def _make_transparent(self):
        # A semi-hack to make the QQuickWidget have transparent background, see:
        # https://doc.qt.io/qt-6/qquickwidget.html#limitations
        self.setAttribute(Qt.WidgetAttribute.WA_AlwaysStackOnTop)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self.setClearColor(Qt.GlobalColor.transparent)


    def _configure_supported_languages(self):
        locales = []
        try:
            with open(PLAYOS_LANGUAGES_CONFIG, "r") as f:
                locales_json = json.load(f)
                locales += [l['locale'].split(".")[0] for l in locales_json]
        except FileNotFoundError:
            logging.warning(f"Locale file {PLAYOS_LANGUAGES_CONFIG} not found.")

        # ensure en_US always present and is the first element to act as fallback
        if "en_US" in locales:
            locales.remove("en_US")
        locales = ["en_US"] + locales

        # extra custom locales for testing
        extra_locales = PLAYOS_LANGUAGES_EXTRA.split(";")
        locales += extra_locales

        self.rootContext().setContextProperty("activeLocales", ";".join(locales))


    def __init__(self, parent):
        super(KeyboardWidget, self).__init__(parent)

        self._configure_supported_languages()

        input_panel_qml = importlib.resources.files('kiosk_browser').joinpath('inputpanel.qml')
        with importlib.resources.as_file(input_panel_qml) as f:
            widget_qml = QUrl.fromLocalFile(str(f))
            self.setSource(widget_qml)
            if self.status() == QQuickWidget.Status.Error:
                errors_str = "\n".join([e.toString() for e in self.errors()])
                raise RuntimeError(f"Failed to initialize inputpanel.qml:\n {errors_str}")

        # needed for keyboardBackgroundNumeric to work, see inputpanel.qml
        self._make_transparent()

        # in case someone tries to use this on an actual touch device
        self.setAttribute(Qt.WidgetAttribute.WA_AcceptTouchEvents)
        self.setFocusPolicy(Qt.FocusPolicy.NoFocus)

        self.setResizeMode(QQuickWidget.ResizeMode.SizeRootObjectToView);

        self._escape_key_filter = EscapeKeyFilter(self)

        self._input_method = QApplication.inputMethod()

        # Note: The interleaving of cursorRectangleChanged and visibleChanged events
        # seems to depend on the input field focus sequence, so we simply respond to both
        self._input_method.cursorRectangleChanged.connect(self._reposition)
        self._input_method.visibleChanged.connect(self._reposition)
        self._reposition()

    # The QQuickWidget holding the virtual keyboard is sized and positioned
    # explicitly w.r.t. the parent window (see _resize and _reposition).
    #
    # An alternative approach would be to make the QQuickWidget take the size of
    # the whole window, enable transparency (see _make_transparent), make the
    # InputPanel a sub-element and move the positioning of the keyboard logic to
    # QML. However, this would prevent interaction with the page items
    # underneath the keyboard (until it is hidden) and might have other
    # unexpected consequences.
    def _resize(self):
        self.resize(QSize(round(self._visibleWidth()), round(self._visibleHeight())))

    def _visibleWidth(self):
        return self.window().width() / 2

    def _visibleHeight(self):
        # Hard-coded keyboardDesignHeight / keyboardDesignWidth values from
        # qtvirtualkeyboard's default/style.qml
        # Would be better to somehow read them from `QtQuick.VirtualKeyboard.Styles`?
        return round(self._visibleWidth() * 800 / 2560)

    # Move the virtual keyboard to the top or bottom of the screen depending on
    # where the text input cursor is currently, hide the keyboard if no input is
    # requested.
    def _reposition(self):
        if not self._input_method.isVisible():
            self.hide()
            return

        cursorTop = self._input_method.cursorRectangle().top()

        # Note: could also shift left/right using cursorRectangle().left() here
        kbdX = round((self.window().width() - self._visibleWidth()) / 2)

        if cursorTop > (self.window().height() / 2):
            # move to the top
            kbdY = 0
        else:
            # move to bottom
            kbdY = round(self.window().height() - self._visibleHeight())

        self.move(QPoint(kbdX, kbdY))
        self.show()
