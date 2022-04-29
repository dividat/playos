from PyQt5 import QtWidgets, QtCore, QtGui, QtWebEngineWidgets

# Dialog width and height ratio compared to the parent’s size.
dialog_ratio = 0.8

# Window border thickness and color
window_border = 2
window_color = '#222222'

def widget(parent, title, url, additional_close_keys, on_close):
    """ Embed a web view in a dialog.

        Close with ESC, additional_close_keys, or clicking on the cross.
    """

    dialog = QtWidgets.QDialog(parent)
    w = parent.width()
    h = parent.height()
    dialog.setGeometry(w * (1 - dialog_ratio) / 2, h * (1 - dialog_ratio) / 2, w * dialog_ratio, h * dialog_ratio)

    show_webview_window(dialog, title, url)

    for key in set(['ESC', *additional_close_keys]):
        QtWidgets.QShortcut(key, dialog).activated.connect(dialog.close)

    # Finish after close
    dialog.finished.connect(lambda: finish(parent, dialog, on_close))

    return dialog

def show_webview_window(dialog, title, url):
    """ Show webview window with decorations.
    """

    widget = QtWidgets.QWidget(dialog)
    widget.setGeometry(0, 0, dialog.width(), dialog.height())
    widget.setStyleSheet(f"background-color: {window_color};")

    layout = QtWidgets.QVBoxLayout(widget)
    layout.setContentsMargins(window_border, 0, window_border, window_border) # left, top, right, bottom
    widget.setLayout(layout)

    layout.addWidget(title_line(dialog, title))

    webview = QtWebEngineWidgets.QWebEngineView(dialog)
    webview.page().setUrl(url)
    layout.addWidget(webview)

def title_line(dialog, title):
    """ Title and close button.
    """

    line = QtWidgets.QWidget(dialog)
    line.setFixedHeight(30)

    label = QtWidgets.QLabel(title)
    label.setStyleSheet("""
        color: white;
        font-family: monospace;
        font-size: 16px;
    """);

    button = QtWidgets.QPushButton("❌", dialog)
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
    button.clicked.connect(dialog.close)

    layout = QtWidgets.QHBoxLayout()
    layout.setContentsMargins(5, 5, 5, 0) # left, top, right, bottom
    layout.addWidget(label)
    layout.addStretch(1)
    layout.addWidget(button)
    line.setLayout(layout)

    return line

def finish(parent, dialog, on_close):
    """ Give back the focus to the parent.
    """

    parent.activateWindow()
    on_close()
