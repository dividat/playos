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


def parse_args():
    parser = argparse.ArgumentParser(
        description="PlayOS network watchdog",
        epilog="See the nix watchdog module for extra documentation"
    )
    parser.add_argument('--check-url', dest="check_urls", nargs='+', action='append', required=True)
    parser.add_argument('--check-interval', type=int, required=True)
    parser.add_argument('--max-num-failures', type=int, required=True)
    parser.add_argument('--setting-change-delay', type=int, required=True)
    return parser.parse_args()


class State(enum.StrEnum):
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
        print(f"Check URL failed: {err}, sleeping for {cfg.check_interval} seconds")
        check_sleep(cfg)
        return State.NEVER_CONNECTED
    else:
        print(f"Detected successful connection to {cfg.check_url}")
        return State.ONCE_CONNECTED


def run_state_once_connected(cfg, remain_attempts) -> Tuple[State, int]:
    if remain_attempts > 0:
        err = perform_url_checks(cfg.check_url)
        if err:
            print(f"Check URL failed: {err}")
            remain_attempts -= 1
        else:
            print("Check URL successful")
            remain_attempts = cfg.max_num_failures

        check_sleep(cfg)

    return (State.DISCONNECTED, 0)


def run_state_disconnected(cfg) -> State:
    subprocess.run(CONNMAN_RESTART_COMMAND, shell=True, check=False)

    return State.NEVER_CONNECTED


def run_state_setting_change_delay(cfg, change_time) -> State:
    elasped_time = datetime.datetime.now() - change_time
    remaining_sleep_seconds = cfg.setting_change_delay - elasped_time.total_seconds()
    if remaining_sleep_seconds > 0:
        time.sleep(remaining_sleep_seconds)

    return State.NEVER_CONNECTED


def start_dbus_monitor_thread(on_changed):
    DBusGMainLoop(set_as_default=True)

    bus = dbus.SystemBus()

    def monitor():
        bus.add_signal_receiver(
            handler_function=on_changed,
            bus_name='net.connman.Service',
            member_keyword='PropertyChanged'
        )
        loop = GLib.MainLoop()
        loop.run()

    thread = threading.Thread(target=monitor, args=[])
    thread.daemon = True
    thread.start()


def run(cfg):
    state = State.NEVER_CONNECTED
    remain_attempts = cfg.max_num_failures
    last_connman_setting_change = datetime.datetime.now() - datetime.timedelta(seconds=cfg.setting_change_delay + 1)

    def update_last_connman_setting_change(*args, **kwargs):
        # TODO: is this necessary?
        global last_connman_setting_change
        last_connman_setting_change = datetime.datetime.now()
        print(f"{last_connman_setting_change=}")

    start_dbus_monitor_thread(update_last_connman_setting_change)

    while True:
        now = datetime.datetime.now()

        print(f"IN MAIN: {last_connman_setting_change=}")

        if (now - last_connman_setting_change).total_seconds() < cfg.setting_change_delay:
            # override state, because there are recent connman changes
            state = State.SETTING_CHANGE_DELAY

        print(f"Watchdog state: {state}")
        match state:
            case State.NEVER_CONNECTED:
                state = run_state_never_connected(cfg)
                remain_attempts = cfg.max_num_failures

            case State.ONCE_CONNECTED:
                state, remain_attempts = run_state_once_connected(cfg, remain_attempts)

            case State.DISCONNECTED:
                state = run_state_disconnected(cfg)

            case State.SETTING_CHANGE_DELAY:
                state = run_state_setting_change_delay(cfg, last_connman_setting_change)


def main():
    args = parse_args()
    run(args)


if __name__ == "__main__":
    main()
