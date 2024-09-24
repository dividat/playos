import sys
import logging
import signal
from PyQt5.QtCore import Qt, QUrl, QSize
from PyQt5.QtGui import QKeySequence
from PyQt5.QtWidgets import QApplication

from kiosk_browser import main_widget

def start(kiosk_url, settings_url, toggle_settings_key, fullscreen = True):

    logging.basicConfig(level=logging.INFO)

    app = QApplication(sys.argv)

    mainWidget = main_widget.MainWidget(
        kiosk_url = parseUrl(kiosk_url),
        settings_url = parseUrl(settings_url),
        toggle_settings_key = QKeySequence(toggle_settings_key)
    )

    mainWidget.setContextMenuPolicy(Qt.NoContextMenu)

    screen_size = app.primaryScreen().size()

    if fullscreen:
        # Without a Window Manager, showFullScreen does not work under X,
        # so set the window size to the primary screen size.
        mainWidget.resize(screen_size)
        mainWidget.showFullScreen()
    else:
        mainWidget.resize(QSize(round(screen_size.width() / 2), round(screen_size.height() / 2)))
        mainWidget.show()

    # Quit application when receiving SIGINT
    def on_SIGINT(signum, frame):
       print('Exiting…')
       app.quit()
       sys.exit(130)
    signal.signal(signal.SIGINT, on_SIGINT)

    # Start application
    app.exec_()

def parseUrl(url):
    parsed_url = QUrl(url)
    if not parsed_url.isValid():
        raise InvalidUrl('Failed to parse URL "%s"' % url) from Exception
    else:
        return parsed_url
