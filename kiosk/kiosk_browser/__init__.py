import sys
import logging
from PyQt6.QtCore import Qt, QUrl
from PyQt6.QtGui import QKeySequence
from PyQt6.QtWidgets import QApplication

from kiosk_browser import main_widget

def start(kiosk_url, settings_url, toggle_settings_key, fullscreen = True):

    logging.basicConfig(level=logging.INFO)

    app = QApplication(sys.argv)

    mainWidget = main_widget.MainWidget(
        kiosk_url = parseUrl(kiosk_url),
        settings_url = parseUrl(settings_url),
        toggle_settings_key = QKeySequence(toggle_settings_key)
    )

    mainWidget.setContextMenuPolicy(Qt.ContextMenuPolicy.NoContextMenu)

    if fullscreen:
        set_fullscreen(app, mainWidget)

    app.exec()

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
