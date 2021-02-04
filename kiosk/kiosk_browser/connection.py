"""Monitor the connection

Regularly detect captive portals, unless a proxy is in use."""

import requests
import tempfile
import threading
import time
import logging
from enum import Enum, auto

check_connection_url = 'http://captive.dividat.com/'

class Status(Enum):
    DISCONNECTED = auto()
    CAPTIVE = auto()
    CONNECTED = auto()
    PROXY = auto()

def sleep(status):
    if status == Status.DISCONNECTED or status == Status.CAPTIVE:
        time.sleep(5)
    else:
        time.sleep(60)

class Connection():

    def __init__(self, get_current_proxy, set_captive_portal_url):
        self._status = Status.DISCONNECTED
        self._get_current_proxy = get_current_proxy
        self._set_captive_portal_url = set_captive_portal_url

    def start_monitoring_daemon(self):
        thread = threading.Thread(target=self._check, args=[])
        thread.daemon = True
        thread.start()

    def is_captive(self):
        return self._status == Status.CAPTIVE

    def _check(self):
        while True:
            proxy = self._get_current_proxy()

            if proxy is not None:
                self._set_status(Status.PROXY)
            else:
                try:
                    r = requests.get(check_connection_url, allow_redirects = False)

                    if r.status_code == 200:
                        self._set_status(Status.CONNECTED)

                    elif r.status_code in [301, 302, 303, 307]:
                        self._set_status(Status.CAPTIVE)
                        self._set_captive_portal_url(r.headers['Location'])

                    else:
                        self._set_status(Status.DISCONNECTED)

                except requests.exceptions.RequestException as e:
                    self._set_status(Status.DISCONNECTED)
                    logging.error('Connection request exception: ' + str(e))

                except Exception as e:
                    self._set_status(Status.DISCONNECTED)
                    logging.error('Connection exception: ' + str(e))

            sleep(self._status)

    def _set_status(self, status):
        self._status = status
        if self._status != Status.CAPTIVE:
            self._set_captive_portal_url('')
