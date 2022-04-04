""" Embed a web view inside a dialog.

Close with ESC, additional_close_keys, or clicking on the cross.
"""

from PyQt5 import QtWidgets, QtCore, QtGui, QtWebEngineWidgets

# Config
dialog_ratio = 0.8
window_border = 2
window_color = '#222222'

class WebviewDialog(QtWidgets.QDialog):

    def __init__(self, parent, title, additional_close_keys, on_close):

        QtWidgets.QDialog.__init__(self, parent)

        self._parent = parent
        self._title = title
        self._on_close = on_close
        self._webview = QtWebEngineWidgets.QWebEngineView(self)
        self._layout = QtWidgets.QVBoxLayout()

        # Close with shortcuts
        for key in set(['ESC', *additional_close_keys]):
            QtWidgets.QShortcut(key, self).activated.connect(self.close)

        # Finish after close
        self.finished.connect(self._finish)

    def show(self, url):
        """ Show dialog on top of the current window.
        """

        # Set dialog size
        w = self._parent.width()
        h = self._parent.height()
        self.setGeometry(w * (1 - dialog_ratio) / 2, h * (1 - dialog_ratio) / 2, w * dialog_ratio, h * dialog_ratio)

        # Reload the webview (prevent keeping previous scroll position)
        self._webview.setUrl(url)

        self._show_window()
        self.exec_()

    # Private

    def _show_window(self):
        """ Show decorated window containing the webview.
        """

        window = QtWidgets.QWidget(self)
        window.setGeometry(0, 0, self.width(), self.height())
        window.setStyleSheet(f"background-color: {window_color};")

        layout = QtWidgets.QVBoxLayout(window)
        layout.setContentsMargins(window_border, 0, window_border, window_border) # left, top, right, bottom
        window.setLayout(layout)

        layout.addWidget(self._title_line())
        layout.addWidget(self._webview)

    def _title_line(self):
        """ Title and close button.
        """

        line = QtWidgets.QWidget(self)
        line.setFixedHeight(30)

        label = QtWidgets.QLabel(self._title, self)
        label.setStyleSheet("""
            color: white;
            font-family: monospace;
            font-size: 16px;
        """);

        button = QtWidgets.QPushButton("❌", self)
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
        button.clicked.connect(self.close)

        layout = QtWidgets.QHBoxLayout(self)
        layout.setContentsMargins(5, 5, 5, 0) # left, top, right, bottom
        layout.addWidget(label)
        layout.addStretch(1)
        layout.addWidget(button)
        line.setLayout(layout)

        return line

    def _finish(self):
        """ Cleanup webview and give back focus to the parent
        """

        self._webview.setHtml("") 
        self._parent.activateWindow()
        self._on_close()
