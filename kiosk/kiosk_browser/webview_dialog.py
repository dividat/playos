from PyQt5 import QtWidgets, QtCore, QtGui, QtWebEngineWidgets

# Dialog width and height ratio compared to the parent’s size.
dialog_ratio = 0.8

# Window border thickness and color
window_border = 2
window_color = '#222222'

def widget(parent, title, url, additional_close_keys, on_dialog_close):
    """ Embed a web view in a dialog.

        Close with ESC, additional_close_keys, or clicking on the cross.
    """

    dialog = QtWidgets.QDialog(parent)
    w = parent.width()
    h = parent.height()
    dialog.setGeometry(w * (1 - dialog_ratio) / 2, h * (1 - dialog_ratio) / 2, w * dialog_ratio, h * dialog_ratio)

    overlay = show_overlay(parent)
    on_close = lambda: close(parent, overlay, dialog, on_dialog_close)
    show_webview_window(dialog, title, url, on_close)

    for key in set(['ESC', *additional_close_keys]):
        QtWidgets.QShortcut(key, dialog).activated.connect(on_close)

    overlay.show()
    return dialog

def show_overlay(parent):
    """ Show overlay on all the surface of the parent.
    """

    widget = QtWidgets.QWidget(parent)
    widget.setGeometry(0, 0, parent.width(), parent.height())
    widget.setStyleSheet("background-color: rgba(0, 0, 0, 0.4)")
    return widget

def show_webview_window(parent, title, url, on_close):
    """ Show webview window with decorations.
    """

    widget = QtWidgets.QWidget(parent)
    widget.setGeometry(0, 0, parent.width(), parent.height())
    widget.setStyleSheet(f"background-color: {window_color};")

    layout = QtWidgets.QVBoxLayout(widget)
    layout.setContentsMargins(window_border, 0, window_border, window_border) # left, top, right, bottom
    widget.setLayout(layout)

    layout.addWidget(title_line(widget, title, on_close))

    webview = QtWebEngineWidgets.QWebEngineView(parent)
    webview.page().setUrl(url)
    layout.addWidget(webview)

def title_line(parent, title, on_close):
    """ Title and close button.
    """

    line = QtWidgets.QWidget(parent)
    line.setFixedHeight(30)

    label = QtWidgets.QLabel(title)
    label.setStyleSheet("""
        color: white;
        font-family: monospace;
        font-size: 16px;
    """);

    button = QtWidgets.QPushButton("❌", parent)
    button.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))
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

def close(parent, overlay, dialog, on_close):
    """ Close dialog and give back the focus to the parent.
    """

    overlay.setParent(None)
    dialog.close()
    parent.activateWindow()
    on_close()
