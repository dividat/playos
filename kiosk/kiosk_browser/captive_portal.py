"""Detect captive portals

Regularly monitor the connection. Ignore captive portals if the connection is
behind a proxy."""

import requests
import tempfile
import threading
import time
import logging
from enum import Enum, auto
from http import HTTPStatus
from PyQt6 import QtWidgets
from typing import Callable

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

def is_redirect(status_code):
    """Check whether a status code is a redirect that is mandatorily paired with a location header."""
    return status_code in [
        HTTPStatus.MOVED_PERMANENTLY,
        HTTPStatus.FOUND,
        HTTPStatus.SEE_OTHER,
        HTTPStatus.TEMPORARY_REDIRECT,
        HTTPStatus.PERMANENT_REDIRECT
    ]

def is_likely_replaced_page(status_code):
    """Check whether a status code is known or surmised to be used by captive portals that replace page contents."""
    return status_code in [
        HTTPStatus.OK,
        HTTPStatus.UNAUTHORIZED,
        HTTPStatus.PROXY_AUTHENTICATION_REQUIRED,
        HTTPStatus.NETWORK_AUTHENTICATION_REQUIRED
    ]

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

                    if r.status_code == HTTPStatus.OK and 'Open Sesame' in r.text:
                        self._status = Status.DIRECT_CONNECTED

                    elif is_redirect(r.status_code):
                        self._status = Status.DIRECT_CAPTIVE
                        self.show_captive_portal_message(r.headers['Location'])

                    elif is_likely_replaced_page(r.status_code):
                        self._status = Status.DIRECT_CAPTIVE
                        self.show_captive_portal_message(check_connection_url)

                    else:
                        self._status = Status.DIRECT_DISCONNECTED

                except requests.exceptions.RequestException as e:
                    self._status = Status.DIRECT_DISCONNECTED
                    logging.error('Connection request exception: ' + str(e))

                except Exception as e:
                    self._status = Status.DIRECT_DISCONNECTED
                    logging.error('Connection exception: ' + str(e))

            sleep(self._status)

class OpenMessage(QtWidgets.QWidget):
    """ Message inviting the user to open a captive portal.

    Can be hidden and showed, keeping its position in the tree.
    """

    def __init__(
            self,
            on_open: Callable[[], None],
            parent: QtWidgets.QWidget):

        QtWidgets.QWidget.__init__(self, parent)

        label = QtWidgets.QLabel('You must log in to this network before you can access the Internet.')

        button = QtWidgets.QPushButton('Open Network Login Page')
        button.clicked.connect(on_open)

        message_layout = QtWidgets.QHBoxLayout()
        message_layout.addWidget(label)
        message_layout.addStretch(1)
        message_layout.addWidget(button)

        self._message_widget = QtWidgets.QWidget()
        self._message_widget.setLayout(message_layout)
        self._message_widget.setStyleSheet("background-color: #e0e0e0;")

        self._layout = QtWidgets.QHBoxLayout()
        self._layout.setContentsMargins(0, 0, 0, 0)
        self.setLayout(self._layout)

    def show(self):
        self._layout.addWidget(self._message_widget)

    def hide(self):
        self._message_widget.setParent(None)

    def is_open(self):
        return self._message_widget.parentWidget() != None
