from PyQt5 import QtWidgets, QtCore, QtGui
from PyQt5.QtWebEngineWidgets import QWebEngineView

def widget(parent, title, url, toggle_parameters_key):
    """ Embed a web view in a dialog.
    """

    dialog = QtWidgets.QDialog(parent)
    dialog.setFixedSize(parent.width() * 0.8, parent.height() * 0.8)
    dialog.setStyleSheet("background-color: #285577;")

    on_close = lambda: close(parent, dialog)

    layout = QtWidgets.QVBoxLayout(dialog)
    layout.setContentsMargins(2, 0, 2, 2) # left, top, right, bottom
    dialog.setLayout(layout)

    layout.addWidget(title_line(dialog, title, on_close))

    webview = QWebEngineView()
    webview.page().setUrl(url)
    layout.addWidget(webview)

    # Close with: toggle key, escape
    QtWidgets.QShortcut(toggle_parameters_key, dialog).activated.connect(on_close)
    QtWidgets.QShortcut('ESC', dialog).activated.connect(on_close)

    return dialog

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

def close(parent, dialog):
    """ Close dialog and give focus back to the parent.
    """

    dialog.close()
    parent.activateWindow()
