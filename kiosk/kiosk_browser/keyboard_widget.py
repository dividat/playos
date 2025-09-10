from __future__ import annotations # allow forward references in types

import importlib.resources
from PyQt6 import QtCore
from PyQt6.QtCore import QUrl, Qt, QPoint, QSize
from PyQt6.QtQuickWidgets import QQuickWidget
from PyQt6.QtWidgets import QApplication
import json
import logging
import os
from enum import IntEnum, auto
from typing import Optional

PLAYOS_LANGUAGES_CONFIG = "/etc/playos/languages.json"
# for easier testing, semicolon separated, e.g. de_DE;fr_FR
PLAYOS_LANGUAGES_EXTRA = os.getenv("PLAYOS_LANGUAGES_EXTRA", "")


# The virtual keyboard's activation state. Used to manually control the
# visibility of the virtual keyboard via Enter/Escape and HideKeyboardKey keys.
#
# For internal use only. Use QApplication.inputMethod().isVisible() for
# situations where you just need to know if the virtual keyboard is active and
# visible.
class ActivationState(IntEnum):
    # A transient state that represents an indeterminate situation.
    # E.g. after the cursor moves, we do not know if it has moved to a new field
    # (in which case the virtual keyboard should be hidden) or inside of the
    # same field (in which case the virtual keyboard state remains unchanged)
    # See KeyboardWidget._cursorMoved for more details
    UNKNOWN = auto()

    # We have "intercepted" the InputMethod::show() and undone it with a hide().
    # Waiting for user to press Enter/OK to activate the virtual keyboard.
    # Keyboard is not visible. Cursor is inside an input field.
    WAITING_FOR_ACTIVATION = auto()

    # User has pressed Enter/OK and we activated the virtual keyboard.
    # Keyboard is visible (or will soon become). Cursor is inside an input field.
    ACTIVATED = auto()



# "Globally" handle Escape/Enter/Return keys for toggling keyboard visibility..
# Prevents both the KeyPress and the following KeyRelease from reaching any Qt
# objects if they trigger any action.
class ActivationKeyFilter(QtCore.QObject):
    def __init__(self, parent: KeyboardWidget):
        super().__init__(parent)

        self._supress_next_key_release: Optional[QtCore.Qt.Key] = None

        QApplication.instance().installEventFilter(self)

    # Note: installed for the top-level QApplication instance, so this is
    # performance-sensitive.
    def eventFilter(self, source, event):
        if event.type() == QtCore.QEvent.Type.KeyPress:
            self._supress_next_key_release = None

            if event.key() in [ QtCore.Qt.Key.Key_Enter, QtCore.Qt.Key.Key_Return ]:
                if self.parent().isSuspended():
                    self.parent().activateKeyboard()
                    self._supress_next_key_release = event.key()
                    return True

            elif event.key() == QtCore.Qt.Key.Key_Escape:
                if QApplication.inputMethod().isVisible():
                    self.parent().suspendKeyboard()
                    self._supress_next_key_release = event.key()
                    return True

        elif event.type() == QtCore.QEvent.Type.KeyRelease:
            # stop KeyRelease propagation too if we just closed or open the keyboard
            return event.key() == self._supress_next_key_release

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

        self._activation_key_filter = ActivationKeyFilter(self)

        self._input_method = QApplication.inputMethod()

        self._state = ActivationState.UNKNOWN
        self.hide()
        self._resize()

        # Custom signal emitted from QML to detect hiding via user action.
        # Note: the HideKeyboardKey automatically hides the keyboard, but we
        # call the generic `suspendKeyboard` to not rely on the event ordering
        self.rootObject().hideKeyboardClicked.connect(self.suspendKeyboard)

        self._input_method.cursorRectangleChanged.connect(self._cursorMoved)
        self._input_method.visibleChanged.connect(self._visibleChanged)

    # The QQuickWidget holding the virtual keyboard is sized and positioned
    # explicitly w.r.t. the parent window (see _resize and _cursorMoved).
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

    # Mark keyboard as active and display it on the screen
    def activateKeyboard(self):
        self._state = ActivationState.ACTIVATED
        QApplication.inputMethod().show()

    # Prevent the keyboard from being displayed and mark it as waiting for (user) activation
    def suspendKeyboard(self):
        QApplication.inputMethod().hide()
        # indicate the keyboard is suspended
        self._state = ActivationState.WAITING_FOR_ACTIVATION

    # Was the keyboard suspended with suspendKeyboard? (i.e. is it waiting for user activation)
    def isSuspended(self):
        return self._state == ActivationState.WAITING_FOR_ACTIVATION

    def _visibleChanged(self):
        if self._input_method.isVisible():
            # User has activated the keyboard, so show ourselves
            if self._state == ActivationState.ACTIVATED:
                self.show()

            # Something in the platform is trying to show the keyboard, but we
            # delay until the user manually activates it.
            else:
                self.suspendKeyboard()

        else:
            # Handle keyboard hiding the same regardless of reason.
            #
            # This state will be overridden afterwards if the keyboard is being
            # suspended or hidden via a user interaction (Esc/HideKeyboardKey),
            # see `suspendKeyboard`
            self._state = ActivationState.UNKNOWN

            self.hide()


    # Move the virtual keyboard to the top or bottom of the screen depending on
    # where the text input cursor is currently. Mark the ActivationState as UNKNOWN.
    #
    # Note: when an input field is unfocused, cursorRectangle() seems to be equal
    # to the last/previous cursor position, instead of something like null.
    def _cursorMoved(self):
        # Respond to any cursor movement by setting a transitional UNKNOWN state.
        #
        # There are 3 possible movements:
        #   1. Cursor moved inside a single input field.
        #   2. Cursor moved to a different input field
        #   3. Input field is unfocused (cursor "gone", position is stale - see Note above)
        #
        # In theory we only care about the last case, since we want to unset
        # the WAITING_FOR_ACTIVATION state if the user navigates away from an
        # input field. However, it does not seem to be possible to distinguish
        # between the cases with the current Qt APIs, so instead we treat them
        # all the same.
        #
        # We expect Qt platform to signal visibleChanged LATER, thus giving us a
        # chance to override the state in the _visibleChanged handler. At the
        # moment that seems to be the case: cursorRectangleChanged events are
        # always received before visibleChanged events (which makes sense - the
        # platform needs to know the location of input before it can determine
        # what kind of input to request). If the event order changes in future
        # Qt releases, this will break.
        self._state = ActivationState.UNKNOWN

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
