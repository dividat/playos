import sys
import logging
from PyQt5.QtCore import Qt, QUrl
from PyQt5.QtGui import QKeySequence
from PyQt5.QtWidgets import QApplication

from kiosk_browser import main_widget, proxy

def start(primary_url, secondary_url, toggle_sequence, fullscreen = True):

    logging.basicConfig(level=logging.INFO)

    app = QApplication(sys.argv)

    p = proxy.get_from_connman()
    if p != "":
        proxy.use_in_qt_app(p)

    mainWidget = main_widget.MainWidget(
        urls = [parseUrl(primary_url), parseUrl(secondary_url)],
        toggle_sequence = QKeySequence(toggle_sequence),
        proxy = p
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
