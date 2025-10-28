from PyQt6 import QtWidgets, QtCore, QtGui
from typing import Callable

from kiosk_browser.keyboard_detector import KeyboardDetector
from kiosk_browser.ui import LightButton

overlay_color: str = '#888888'

dialog_ratio: float = 0.8
dialog_border: int = 2
dialog_color: str = '#222222'

class DialogableWidget(QtWidgets.QWidget):
    """ Embed widget, allowing to decorate and undecorate with dialog look.
    """

    def __init__(
            self,
            parent: QtWidgets.QWidget,
            inner_widget: QtWidgets.QWidget,
            on_close: Callable[[], None],
            keyboard_detector: KeyboardDetector):

        QtWidgets.QWidget.__init__(self, parent)

        self._inner_widget = inner_widget
        self._is_decorated = False
        self._on_close = on_close
        self._keyboard_detector = keyboard_detector

        # Overlay
        self.setStyleSheet(f"background-color: {overlay_color};")

        # Stretch view so that it takes all the space
        policy = QtWidgets.QSizePolicy()
        policy.setVerticalStretch(1)
        policy.setHorizontalStretch(1)
        policy.setVerticalPolicy(QtWidgets.QSizePolicy.Policy.Preferred)
        policy.setHorizontalPolicy(QtWidgets.QSizePolicy.Policy.Preferred)
        self.setSizePolicy(policy)

        # Layout
        self._layout = QtWidgets.QVBoxLayout(self)
        self._layout.setContentsMargins(0, 0, 0, 0)
        self._layout.addWidget(self._inner_widget)
        self.setLayout(self._layout)

    def decorate(self, title: str):
        if not self._is_decorated:
            self._inner_widget.setParent(None)
            self._dialog = dialog(self, title, self._inner_widget,
                                  self._on_close, self._keyboard_detector)
            self._layout.addWidget(self._dialog)
            self._inner_widget.setFocus()
            self._is_decorated = True

    def undecorate(self):
        if self._is_decorated:
            self._dialog.hide()
            self._layout.addWidget(self._inner_widget)
            self._is_decorated = False

    def is_decorated(self):
        return self._is_decorated


class KeyboardConnectedIndicator(QtWidgets.QWidget):
    def __init__(self, keyboard_detector: KeyboardDetector):
        super().__init__()

        # https://flaticons.net/custom.php?i=4j8wsOMcQIDIoInIN0ho6gOWfA
        self._pixmap = QtGui.QPixmap("images/keyboard.png")

        self._layout = QtWidgets.QVBoxLayout(self)
        self._layout.setContentsMargins(0, 0, 0, 0)
        self._layout.setSpacing(0)

        self._label = QtWidgets.QLabel(self)
        self._layout.addWidget(self._label, alignment=QtCore.Qt.AlignmentFlag.AlignCenter)

        self._label.setToolTip("Physical keyboard detected - virtual keyboard is disabled")

        keyboard_detector.keyboard_available_changed.connect(self._toggle)
        self._toggle(keyboard_detector.keyboard_available)

    def _toggle(self, physical_keyboard_is_available):
        if physical_keyboard_is_available:
            self._label.show()
        else:
            self._label.hide()

    def _scale_icon(self, size):
        self._label.setPixmap(self._pixmap.scaledToHeight(
            round(size.height() * 0.6),
            mode = QtCore.Qt.TransformationMode.SmoothTransformation
        ))
        self._label.adjustSize()

    def resizeEvent(self, event):
        super().resizeEvent(event)
        self._scale_icon(event.size())


def dialog(
        parent: QtWidgets.QWidget,
        title: str,
        content: QtWidgets.QWidget,
        on_close: Callable[[], None],
        keyboard_detector: KeyboardDetector):

    """ Dialog like widget, with provided widget as content.
    """

    widget = QtWidgets.QWidget(parent)
    horizontal_margin = int(parent.width() * (1 - dialog_ratio) / 2)
    vertical_margin = int(parent.height() * (1 - dialog_ratio) / 2)

    # layout/widget hierarchy:
    # widget
    #   > root_layout
    #       > [spacing] (top margin)
    #       > mid_layout (left/right margins)
    #           > inner_dialog
    #               > inner_dialog_layout
    #                   > title_line
    #                   > content
    #       > keyboard_indicator (bottom margin)

    root_layout = QtWidgets.QVBoxLayout(widget)
    root_layout.setContentsMargins(0, 0, 0, 0)
    root_layout.setSpacing(0)

    # inner_dialog and elements
    inner_dialog = QtWidgets.QWidget(widget)
    inner_dialog.setStyleSheet(f"background-color: {dialog_color};")
    inner_dialog_layout = QtWidgets.QVBoxLayout(inner_dialog)
    inner_dialog_layout.setContentsMargins(dialog_border, 0, dialog_border, dialog_border) # left, top, right, bottom

    inner_dialog_layout.addWidget(title_line(inner_dialog, title, on_close))
    inner_dialog_layout.addWidget(content)

    # extra wrapper to provide left/right margins for the middle section
    mid_layout = QtWidgets.QVBoxLayout()
    # set left/right margins only
    mid_layout.setContentsMargins(horizontal_margin, 0, horizontal_margin, 0)
    mid_layout.addWidget(inner_dialog)

    # footer section
    keyboard_indicator = KeyboardConnectedIndicator(keyboard_detector)
    # note: this also sets the bottom border height
    keyboard_indicator.setFixedSize(vertical_margin, vertical_margin)

    # set up elements on root_layout
    root_layout.addSpacing(vertical_margin) # top margin
    root_layout.addLayout(mid_layout)
    root_layout.addWidget(keyboard_indicator, alignment=QtCore.Qt.AlignmentFlag.AlignRight)

    return widget

def title_line(
        dialog: QtWidgets.QWidget,
        title: str,
        on_close: Callable[[], None]):

    """ Title and close button.
    """

    line = QtWidgets.QWidget(dialog)
    line.setStyleSheet(f"""
        background-color: {dialog_color};
        font-family: monospace;
        font-size: 16px;
    """)
    line.setFixedHeight(30)

    label = QtWidgets.QLabel(title)
    label.setStyleSheet("""
        color: white;
    """)

    button = LightButton("×", dialog)
    button.clicked.connect(on_close)

    layout = QtWidgets.QHBoxLayout()
    layout.setContentsMargins(5, 5, 5, 0) # left, top, right, bottom
    layout.addWidget(label)
    layout.addStretch(1)
    layout.addWidget(button)
    line.setLayout(layout)

    return line
