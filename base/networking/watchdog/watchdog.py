import argparse
import requests
import enum
from enum import auto
import time
import subprocess
from collections import deque
from typing import Tuple
import datetime
import dbus
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib
import threading

CLIENT_HEADERS = {'User-Agent': 'PlayOS watchdog 1.0'}
CONNMAN_RESTART_COMMAND = "systemctl restart connman.service"

DEBUG = False

def log(msg):
    print(msg)


def debug(msg):
    if DEBUG:
        print(f"[DEBUG] {msg}")


def parse_args():
    parser = argparse.ArgumentParser(
        description="PlayOS network watchdog",
        epilog="See the nix watchdog module for extra documentation"
    )
    parser.add_argument('--check-url', dest="check_urls", action='append', required=True,
                        help="Flag can be repeated multiple times")
    parser.add_argument('--check-interval', type=int, required=True)
    parser.add_argument('--max-num-failures', type=int, required=True)
    parser.add_argument('--setting-change-delay', type=int, required=True)
    parser.add_argument('--debug', action='store_true')
    return parser.parse_args()


class UpperStrEnum(enum.StrEnum):
    @staticmethod
    def _generate_next_value_(name, *args):
        return name.upper()


class State(UpperStrEnum):
    NEVER_CONNECTED = auto()
    ONCE_CONNECTED = auto()
    DISCONNECTED = auto()
    SETTING_CHANGE_DELAY = auto()


# Returns None if successful or error message if failed
def perform_single_url_check(url):
    # TODO: lookup proxy in connman if configured
    failure = None
    try:
        # stream=True avoids downloading the content, which we don't care about
        r = requests.get(url, headers=CLIENT_HEADERS, stream=True, allow_redirects=True)
        if r.status_code != 200:
            failure = RuntimeError(f"Bad HTTP status code: {r.status_code}")
    except Exception as e:
        failure = RuntimeError(f"Failed to connect: {e}")

    if failure:
        debug(f"URL check for {url} failed with {failure}")
    else:
        debug(f"URL check for {url} succeeded!")

    return failure


def perform_url_checks(urls):
    url_queue = deque(urls)
    while url_queue:
        next_url = url_queue.popleft()
        check_result = perform_single_url_check(next_url)

        if check_result is None:
            return
        else:
            continue

    return RuntimeError("Connectivity check failed for all URLs")


def check_sleep(cfg):
    time.sleep(cfg.check_interval)


def run_state_never_connected(cfg) -> State:
    err = perform_url_checks(cfg.check_urls)
    if err:
        log(f"Check URL failed for all URLs, sleeping for {cfg.check_interval} seconds")
        check_sleep(cfg)
        return State.NEVER_CONNECTED
    else:
        log(f"Detected successful internet connection")
        return State.ONCE_CONNECTED


def run_state_once_connected(cfg, remain_attempts) -> Tuple[State, int]:
    if remain_attempts > 0:
        err = perform_url_checks(cfg.check_urls)
        if err:
            remain_attempts -= 1
            log(f"Check URLs failed, remaining attempts: {remain_attempts}")
            check_sleep(cfg)
            return (State.ONCE_CONNECTED, remain_attempts)
        else:
            log("Check URL successful, ")
            remain_attempts = cfg.max_num_failures
            check_sleep(cfg)
            return (State.ONCE_CONNECTED, remain_attempts)

    else:
        log(f"Check URLs failed {cfg.max_num_failures} times, internet connection considered lost.")
        return (State.DISCONNECTED, 0)


def run_state_disconnected(cfg) -> State:
    log("Restarting connman")
    subprocess.run(CONNMAN_RESTART_COMMAND, shell=True, check=False)

    return State.NEVER_CONNECTED


def run_state_setting_change_delay(cfg, elasped_time) -> State:
    remaining_sleep_seconds = cfg.setting_change_delay - round(elasped_time.total_seconds())
    if remaining_sleep_seconds > 0:
        debug(f"Sleeping for {remaining_sleep_seconds} seconds after connman update")
        time.sleep(remaining_sleep_seconds)

    return State.NEVER_CONNECTED


class ConnmanDbusMonitor:
    def __init__(self):
        DBusGMainLoop(set_as_default=True)
        self._bus = dbus.SystemBus()
        self._thread = None
        self.last_update = datetime.datetime.fromtimestamp(0)

    def start_monitoring(self):
        def monitor():
            debug("Starting DBus monitoring thread")

            self._bus.add_signal_receiver(
                handler_function=self._mark_update,
                bus_name='net.connman',
                dbus_interface='net.connman.Service',
                signal_name='PropertyChanged',
            )
            loop = GLib.MainLoop()
            loop.run()

        thread = threading.Thread(target=monitor)
        thread.daemon = True
        thread.start()
        self._thread = thread

    def _mark_update(self, *args, **kwargs):
        now = datetime.datetime.now()
        debug(f"connman setting change, setting last_update to {now}")
        self.last_update = now

    
def run(cfg):
    state = State.NEVER_CONNECTED
    remain_attempts = cfg.max_num_failures

    monitor = ConnmanDbusMonitor()
    monitor.start_monitoring()

    while True:
        time_since_update = datetime.datetime.now() - monitor.last_update

        if time_since_update.total_seconds() < cfg.setting_change_delay:
            # override state, because there are recent connman changes
            log("Connman service properties changed, will sleep.")
            state = State.SETTING_CHANGE_DELAY

        debug(f"Current state: {state}")
        match state:
            case State.NEVER_CONNECTED:
                state = run_state_never_connected(cfg)
                remain_attempts = cfg.max_num_failures

            case State.ONCE_CONNECTED:
                state, remain_attempts = run_state_once_connected(cfg, remain_attempts)

            case State.DISCONNECTED:
                state = run_state_disconnected(cfg)

            case State.SETTING_CHANGE_DELAY:
                state = run_state_setting_change_delay(cfg, time_since_update)


def main():
    global DEBUG

    args = parse_args()
    if args.debug:
        DEBUG = True

    run(args)


if __name__ == "__main__":
    main()
