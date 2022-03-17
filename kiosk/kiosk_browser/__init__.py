import sys
import logging
from PyQt5.QtCore import Qt, QUrl
from PyQt5.QtGui import QKeySequence
from PyQt5.QtWidgets import QApplication

from kiosk_browser import main_widget

def start(kiosk_url, parameters_url, toggle_parameters_key, fullscreen = True):

    logging.basicConfig(level=logging.INFO)

    app = QApplication(sys.argv)

    mainWidget = main_widget.MainWidget(
        kiosk_url = parseUrl(kiosk_url),
        parameters_url = parseUrl(parameters_url),
        toggle_parameters_key = QKeySequence(toggle_parameters_key)
    )

    mainWidget.setContextMenuPolicy(Qt.NoContextMenu)

    if fullscreen:
        set_fullscreen(app, mainWidget)

    app.exec_()

def parseUrl(url):
    parsed_url = QUrl(url)
    if not parsed_url.isValid():
        raise InvalidUrl('Failed to parse URL "%s"' % url) from Exception
    else:
        return parsed_url

def set_fullscreen(app, mainWidget):
    # Without a Window Manager, showFullScreen does not work under X,
    # so set the window size to the primary screen size.
    screen_size = app.primaryScreen().size()
    mainWidget.resize(screen_size)
    mainWidget.showFullScreen()
