import sys
import itertools
from PyQt5.QtCore import Qt, QUrl
from PyQt5.QtGui import QKeySequence
from PyQt5.QtWidgets import QApplication

from kiosk_browser import main_widget

def start(primary_url, secondary_url, toggle_sequence, fullscreen = True):

    app = QApplication(sys.argv)

    mainWidget = main_widget.MainWidget(
        urls = [parseUrl(primary_url), parseUrl(secondary_url)],
        toggle_sequence = QKeySequence(toggle_sequence)
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
