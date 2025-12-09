import sys
import os
import logging
import signal
from PyQt6.QtCore import Qt, QUrl
from PyQt6.QtGui import QKeySequence
from PyQt6.QtWidgets import QApplication

from kiosk_browser import main_widget

# Note: doing this via env variables rather than passing `--webEngineArgs`,
# because the env variable overrides the args (and so is easy to break in tests,
# etc)
def setChromiumFlags(max_cache_size: int):
    curFlags = os.environ.get('QTWEBENGINE_CHROMIUM_FLAGS', "")
    # Workaround for https://bugreports.qt.io/browse/QTBUG-130273 in Qt 6.8.1
    # Should be fixed with QT 6.8.2
    disableFFmpegAllowLists = "--disable-features=FFmpegAllowLists"
    setDiskCacheSize = f"--disk-cache-size={max_cache_size}"
    flags = [curFlags, disableFFmpegAllowLists, setDiskCacheSize]
    os.environ['QTWEBENGINE_CHROMIUM_FLAGS'] = " ".join(flags)


def start(kiosk_url, settings_url, toggle_settings_key, max_cache_size, fullscreen = True):

    logging.basicConfig(level=logging.INFO)

    setChromiumFlags(max_cache_size)

    app = QApplication(sys.argv)
    app.setApplicationName("kiosk-browser")

    mainWidget = main_widget.MainWidget(
        kiosk_url = parseUrl(kiosk_url),
        settings_url = parseUrl(settings_url),
        toggle_settings_key = QKeySequence(toggle_settings_key),
        fullscreen = fullscreen,
        max_cache_size = max_cache_size
    )

    mainWidget.setContextMenuPolicy(Qt.ContextMenuPolicy.NoContextMenu)

    # Note: Qt primary screen != xrandr primary screen
    # Qt will set primary when screen becomes visible, while on
    # xrandr it only changes when `--primary` is explicitly specified
    app.primaryScreenChanged.connect(mainWidget.handle_screen_change,
        type=Qt.ConnectionType.QueuedConnection)
    primary = app.primaryScreen()
    mainWidget.handle_screen_change(primary)

    # Quit application gracefully when receiving SIGINT or SIGTERM
    # This is important to trigger flushing of in-memory DOM storage to disk
    def quit_on_signal(signum, _frame):
       print('Exiting…')
       app.quit()
       sys.exit(128+signum)

    signal.signal(signal.SIGINT, quit_on_signal)
    signal.signal(signal.SIGTERM, quit_on_signal)

    # Start application
    sys.exit(app.exec())

def parseUrl(url):
    parsed_url = QUrl(url)
    if not parsed_url.isValid():
        raise InvalidUrl('Failed to parse URL "%s"' % url) from Exception
    else:
        return parsed_url
