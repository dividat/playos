import requests
import tempfile
import threading
import time

check_connection_url = 'http://127.0.0.1:8000'
# check_connection_url = 'http://captive.apple.com'
sleep_time = 5
is_connected = False

def start_daemon(mainWidget):
    thread = threading.Thread(target=action, args=[mainWidget])
    thread.daemon = True
    thread.start()

def action(mainWidget):
    while True:
        r = requests.get(check_connection_url, allow_redirects = False)

        if r.status_code == 200:
            is_connected = True
            mainWidget.set_captive_portal_url('')
        elif r.status_code in [301, 302, 303, 307]:
            is_connected = False
            mainWidget.set_captive_portal_url(r.headers['Location'])
        else:
            is_connected = False
            mainWidget.set_captive_portal_url('')

        time.sleep(sleep_time)
