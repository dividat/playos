from PyQt6 import QtWidgets, QtCore, QtGui
from typing import Callable

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
            on_close: Callable[[], None]):

        QtWidgets.QWidget.__init__(self, parent)

        self._inner_widget = inner_widget
        self._is_decorated = False
        self._on_close = on_close

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

        # Shortcuts
        # TODO: not usable with remote control
        QtGui.QShortcut('ESC', self).activated.connect(self._on_escape)

    def inner_widget(self):
        return self._inner_widget

    def decorate(self, title: str):
        if not self._is_decorated:
            self._inner_widget.setParent(None)
            self._dialog = dialog(self, title, self._inner_widget, self._on_close)
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

    # Private

    def _on_escape(self):
        if self._is_decorated:
            self._on_close()

def dialog(
        parent: QtWidgets.QWidget,
        title: str,
        content: QtWidgets.QWidget,
        on_close: Callable[[], None]):

    """ Dialog like widget, with provided widget as content.
    """

    widget = QtWidgets.QWidget(parent)
    horizontal_margin = int(parent.width() * (1 - dialog_ratio) / 2)
    vertical_margin = int(parent.height() * (1 - dialog_ratio) / 2)
    widget.setContentsMargins(horizontal_margin, vertical_margin, horizontal_margin, vertical_margin)

    layout = QtWidgets.QVBoxLayout(widget)
    widget.setLayout(layout)

    widget_2 = QtWidgets.QWidget(widget)
    widget_2.setStyleSheet(f"background-color: {dialog_color};")
    layout.addWidget(widget_2)

    layout_2 = QtWidgets.QVBoxLayout(widget_2)
    layout_2.setContentsMargins(dialog_border, 0, dialog_border, dialog_border) # left, top, right, bottom
    widget_2.setLayout(layout_2)

    layout_2.addWidget(title_line(widget_2, title, on_close))
    layout_2.addWidget(content)

    return widget

def title_line(
        dialog: QtWidgets.QWidget,
        title: str,
        on_close: Callable[[], None]):

    """ Title and close button.
    """

    line = QtWidgets.QWidget(dialog)
    line.setStyleSheet(f"background-color: {dialog_color};")
    line.setFixedHeight(30)

    label = QtWidgets.QLabel(title)
    label.setStyleSheet("""
        color: white;
        font-family: monospace;
        font-size: 16px;
    """)

    # TODO: close button not reachable/focusable with remote control (also not
    # intuitive, poorly highlighted when focused)
    button = QtWidgets.QPushButton("×", dialog)
    button.setCursor(QtGui.QCursor(QtCore.Qt.CursorShape.PointingHandCursor))
    button.setStyleSheet("""
        QPushButton {
            background-color: rgba(255, 255, 255, 0.2);
            border: 0;
            color: white;
            font-family: monospace;
            font-size: 18px;
            font-weight: bold;
            padding: 4px 15px 5px;
        }
        QPushButton:hover {
            background-color: rgba(255, 255, 255, 0.3);
        }
    """)
    button.clicked.connect(on_close)

    layout = QtWidgets.QHBoxLayout()
    layout.setContentsMargins(5, 5, 5, 0) # left, top, right, bottom
    layout.addWidget(label)
    layout.addStretch(1)
    layout.addWidget(button)
    line.setLayout(layout)

    return line
