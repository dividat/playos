"""Monitor the connection

Regularly detect captive portals, unless a proxy is in use."""

import requests
import tempfile
import threading
import time
from enum import Enum, auto

check_connection_url = 'http://captive.dividat.com/'
sleep_time_not_connected = 5
sleep_time_connected = 6
sleep_time_proxy = 6

class Status(Enum):
    DISCONNECTED = auto()
    CAPTIVE = auto()
    CONNECTED = auto()
    PROXY = auto()

class Connection():

    def __init__(self, get_current_proxy, set_captive_portal_url):
        self._status = Status.DISCONNECTED
        self._get_current_proxy = get_current_proxy
        self._set_captive_portal_url = set_captive_portal_url

    def start_daemon(self):
        thread = threading.Thread(target=self._check, args=[])
        thread.daemon = True
        thread.start()

    def is_captive(self):
        return self._status == Status.CAPTIVE

    def _check(self):
        while True:
            proxy = self._get_current_proxy()

            if proxy is not None:
                self._status = Status.PROXY
                time.sleep(sleep_time_proxy)
            else:
                try:
                    r = requests.get(
                        check_connection_url,
                        allow_redirects = False)

                    if r.status_code == 200:
                        self._status = Status.CONNECTED
                        self._set_captive_portal_url('')
                    elif r.status_code in [301, 302, 303, 307]:
                        self._status = Status.CAPTIVE
                        self._set_captive_portal_url(r.headers['Location'])
                    else:
                        self._status = Status.DISCONNECTED
                        self._set_captive_portal_url('')

                except requests.exceptions.RequestException as e:
                    print('Connection request exception:', e)
                except Exception as e:
                    print('Connection exception:', e)

                if self._status == Status.CONNECTED:
                    time.sleep(sleep_time_connected)
                else:
                    time.sleep(sleep_time_not_connected)
