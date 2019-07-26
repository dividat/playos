import requests
import tempfile
import threading
import time

check_connection_url = 'http://captive.apple.com/'
sleep_time = 5

class Connection():

    def __init__(self, set_captive_portal_url):
        self._is_connected = False
        self._set_captive_portal_url = set_captive_portal_url

    def start_daemon(self):
        thread = threading.Thread(target=self._check, args=[])
        thread.daemon = True
        thread.start()

    def is_connected(self):
        return self._is_connected

    def _check(self):
        # Initial sleep to be sure _set_captive_portal_url is accessible
        time.sleep(1)

        while True:
            r = requests.get(check_connection_url, allow_redirects = False)

            if r.status_code == 200:
                self._is_connected = True
                self._set_captive_portal_url('')
            elif r.status_code in [301, 302, 303, 307]:
                self._is_connected = False
                self._set_captive_portal_url(r.headers['Location'])
            else:
                self._is_connected = False
                self._set_captive_portal_url('')

            time.sleep(sleep_time)
