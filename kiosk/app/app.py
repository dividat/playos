import sys
import itertools
from PyQt5.QtCore import QUrl
from PyQt5.QtGui import QKeySequence
from PyQt5.QtWidgets import QApplication

from app import main_widget, connection

def start(primary_url, secondary_url, toggle_sequence, fullscreen = True):

    app = QApplication(sys.argv)
    mainWidget = main_widget.MainWidget(
            urls = [parseUrl(primary_url), parseUrl(secondary_url)],
            toggle_sequence = QKeySequence(toggle_sequence))

    connection.start_daemon(mainWidget)

    # self._view.setContextMenuPolicy(Qt.NoContextMenu)
    # if fullscreen:
        # self._fullscreen()

    sys.exit(app.exec_())

def parseUrl(url):
    parsed_url = QUrl(url)
    if not parsed_url.isValid():
        raise InvalidUrl('Failed to parse URL "%s"' % url) from Exception
    else:
        return parsed_url

# def _fullscreen(self):
#     # Without a Window Manager, showFullScreen does not work under X,
#     # so set the window size to the primary screen size.
#     screen_size = self._app.primaryScreen().size()
#     # self._view.resize(screen_size)
#     # self._view.showFullScreen()
