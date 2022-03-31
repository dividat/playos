"""Detect captive portals

Regularly monitor the connection. Ignore captive portals if the connection is
behind a proxy."""

import requests
import tempfile
import threading
import time
import logging
from enum import Enum, auto
from PyQt5 import QtWidgets

check_connection_url = 'http://captive.dividat.com/'

"""
Connection Status

The connection is either behind a proxy, or direct.
"""
class Status(Enum):
    DIRECT_DISCONNECTED = auto()
    DIRECT_CAPTIVE = auto()
    DIRECT_CONNECTED = auto()
    PROXY = auto()

def sleep(status):
    if status == Status.DIRECT_DISCONNECTED or status == Status.DIRECT_CAPTIVE:
        time.sleep(5)
    else:
        time.sleep(60)

class CaptivePortal():

    def __init__(self, get_current_proxy, show_captive_portal_message):
        self._status = Status.DIRECT_DISCONNECTED
        self._get_current_proxy = get_current_proxy
        self.show_captive_portal_message = show_captive_portal_message

    def start_monitoring_daemon(self):
        thread = threading.Thread(target=self._check, args=[])
        thread.daemon = True
        thread.start()

    def _check(self):
        while True:
            proxy = self._get_current_proxy()

            if proxy is not None:
                self._status = Status.PROXY
            else:
                try:
                    r = requests.get(check_connection_url, allow_redirects = False)

                    if r.status_code == 200:
                        self._status = Status.DIRECT_CONNECTED

                    elif r.status_code in [301, 302, 303, 307]:
                        self._status = Status.DIRECT_CAPTIVE
                        self.show_captive_portal_message(r.headers['Location'])

                    else:
                        self._status = Status.DIRECT_DISCONNECTED

                except requests.exceptions.RequestException as e:
                    self._status = Status.DIRECT_DISCONNECTED
                    logging.error('Connection request exception: ' + str(e))

                except Exception as e:
                    self._status = Status.DIRECT_DISCONNECTED
                    logging.error('Connection exception: ' + str(e))

            sleep(self._status)

def open_message(on_open):
    """ Invite the user to open Network Login Page.
    """

    label = QtWidgets.QLabel('You must log in to this network before you can access the Internet.')

    button = QtWidgets.QPushButton('Open Network Login Page')
    button.clicked.connect(on_open)

    layout = QtWidgets.QHBoxLayout()
    layout.addWidget(label)
    layout.addStretch(1)
    layout.addWidget(button)

    widget = QtWidgets.QWidget()
    widget.setLayout(layout)
    return widget
