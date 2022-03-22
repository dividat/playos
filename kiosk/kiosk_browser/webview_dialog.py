from PyQt5 import QtWidgets, QtCore, QtGui, QtWebEngineWidgets

def widget(parent, title, url, additional_close_keys, on_dialog_close):
    """ Embed a web view in a dialog.
    """

    dialog = QtWidgets.QDialog(parent)
    w = parent.width()
    h = parent.height()
    dialog.setGeometry(w * 0.1, h * 0.1, w * 0.8, h * 0.8)

    overlay = show_overlay(parent)
    on_close = lambda: close(parent, overlay, dialog, on_dialog_close)
    show_webview_window(dialog, title, url, on_close)

    # Close with ESC and additional_close_keys
    QtWidgets.QShortcut('ESC', dialog).activated.connect(on_close)
    for key in additional_close_keys:
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
    widget.setStyleSheet("background-color: #285577;")

    layout = QtWidgets.QVBoxLayout(widget)
    layout.setContentsMargins(2, 0, 2, 2) # left, top, right, bottom
    widget.setLayout(layout)

    layout.addWidget(title_line(widget, title, on_close))

    webview = QtWebEngineWidgets.QWebEngineView()
    webview.page().setUrl(url)
    layout.addWidget(webview)

def title_line(parent, title, on_close):
    """ Title and close button.
    """

    line = QtWidgets.QWidget()
    line.setFixedHeight(30)

    label = QtWidgets.QLabel(title)
    label.setStyleSheet("""
        color: white;
        font-family: monospace;
        font-size: 16px;
    """);

    button = QtWidgets.QPushButton("❌")
    button.setCursor(QtGui.QCursor(QtCore.Qt.PointingHandCursor))
    button.setStyleSheet("""
        background-color: transparent;
        border: 0;
        color: white;
        font-family: monospace;
        font-size: 18px;
        font-weight: bold;
    """)
    button.clicked.connect(on_close)

    layout = QtWidgets.QHBoxLayout()
    layout.setContentsMargins(5, 5, 8, 0) # left, top, right, bottom
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
