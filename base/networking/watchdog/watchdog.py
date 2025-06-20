from __future__ import annotations # for recursive State typing
import argparse
import requests
import time
import subprocess
from collections import deque
import datetime
import dbus # type: ignore
from dbus.mainloop.glib import DBusGMainLoop # type: ignore
from gi.repository import GLib # type: ignore
import threading
import math
import proxy_utils
import logging
from dataclasses import dataclass
import enum

CLIENT_HEADERS = {'User-Agent': 'PlayOS watchdog 1.0'}
CONNMAN_RESTART_COMMAND = "systemctl restart connman.service"

logger = logging.getLogger(__name__)

## Helpers

def parse_args():
    parser = argparse.ArgumentParser(
        description="PlayOS network watchdog",
        epilog="See the nix watchdog module for extra documentation"
    )
    parser.add_argument('--check-url', dest="check_urls", action='append', required=True,
                        help="Flag can be repeated multiple times")
    parser.add_argument('--check-interval', type=float, required=True)
    parser.add_argument('--max-num-failures', type=int, required=True)
    parser.add_argument('--check-url-timeout', type=float, required=True)
    parser.add_argument('--setting-change-delay', type=float, required=True)
    parser.add_argument('--debug', action='store_true')
    return parser.parse_args()


def log(msg):
    logger.info(msg)


def debug(msg):
    logger.debug(msg)


# Returns None if successful or error message if failed
def perform_single_url_check(url, timeout, proxy=None):
    failure = None
    proxies = None
    if proxy:
        proxies = { 'http': proxy.to_url() }

    try:
        # stream=True avoids downloading the content, which we don't care about
        r = requests.get(url, headers=CLIENT_HEADERS, timeout=timeout,
                         stream=True, allow_redirects=True, proxies=proxies)
        if r.status_code != 200:
            failure = RuntimeError(f"Bad HTTP status code: {r.status_code}")
    except Exception as e:
        failure = RuntimeError(f"Failed to connect: {e}")

    if failure:
        debug(f"URL check for {url} failed with {failure}")
    else:
        debug(f"URL check for {url} succeeded!")

    return failure


def perform_url_checks(urls, timeout, proxy: proxy_utils.ProxyConf | None):
    url_queue = deque(urls)
    while url_queue:
        next_url = url_queue.popleft()
        check_result = perform_single_url_check(next_url, timeout, proxy=proxy)

        if check_result is None:
            return
        else:
            continue

    return RuntimeError("Connectivity check failed for all URLs")


def check_sleep(cfg):
    time.sleep(cfg.check_interval)


### State ADT

class StateNames(enum.StrEnum):
    NEVER_CONNECTED = "NEVER_CONNECTED"
    ONCE_CONNECTED = "ONCE_CONNECTED"
    DISCONNECTED = "DISCONNECTED"
    SETTING_CHANGE_DELAY = "SETTING_CHANGE_DELAY"

@dataclass(frozen=True)
class StateNeverConnected():
    def __str__(self):
        return StateNames.NEVER_CONNECTED

@dataclass(frozen=True)
class StateOnceConnected:
    remain_attempts: int
    def __str__(self):
        return f"{StateNames.ONCE_CONNECTED} (remain = {self.remain_attempts})"


@dataclass(frozen=True)
class StateDisconnected:
    def __str__(self):
        return StateNames.DISCONNECTED


@dataclass(frozen=True)
class StateSettingChangeDelay:
    time_since_update: datetime.timedelta
    next_state: State
    def __str__(self):
        return StateNames.SETTING_CHANGE_DELAY

State = StateNeverConnected | StateOnceConnected | StateDisconnected | StateSettingChangeDelay

## State actions

def run_state_never_connected(cfg, url_check) -> State:
    err = url_check()
    if err:
        log(f"Check URL failed for all URLs, sleeping for {cfg.check_interval} seconds")
        check_sleep(cfg)
        return StateNeverConnected()
    else:
        log("Detected a working internet connection!")
        return StateOnceConnected(cfg.max_num_failures)


def run_state_once_connected(cfg, url_check, remain_attempts) -> State:
    err = url_check()
    if err:
        remain_attempts -= 1
        if remain_attempts > 0:
            log(f"Check URLs failed, remaining attempts: {remain_attempts}")
            check_sleep(cfg)
            return StateOnceConnected(remain_attempts)

        else:
            log(f"Check URLs failed {cfg.max_num_failures} times, internet connection considered lost.")
            return StateDisconnected()

    else:
        debug("Check URL successful.")
        check_sleep(cfg)
        return StateOnceConnected(cfg.max_num_failures)



def run_state_disconnected(cfg) -> State:
    log("Restarting connman")
    subprocess.run(CONNMAN_RESTART_COMMAND, shell=True, check=False)

    return StateNeverConnected()


def run_state_setting_change_delay(cfg, elasped_time, next_state: State) -> State:
    remaining_delay = cfg.setting_change_delay - elasped_time.total_seconds()
    if remaining_delay > 0:
        sleep_seconds = math.ceil(remaining_delay)
        log(f"Sleeping for {sleep_seconds} seconds after connman setting changes")
        time.sleep(sleep_seconds)
    return next_state

## Connman monitor

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

    def get_current_proxy(self):
        return proxy_utils.get_current_proxy(self._bus)


def make_url_checker(cfg, proxy: None | proxy_utils.ProxyConf):
    return lambda: perform_url_checks(cfg.check_urls, cfg.check_url_timeout, proxy)


def override_state_if_connman_properties_changed(cfg, current_state, last_update) -> State:
    time_since_update = datetime.datetime.now() - last_update

    if time_since_update.total_seconds() < cfg.setting_change_delay:
        # override state, because there are recent connman changes
        debug("Connman service properties changed recently, overriding current state.")
        return StateSettingChangeDelay(time_since_update, next_state=current_state)
    else:
        return current_state


def run(cfg):
    state = StateNeverConnected()

    monitor = ConnmanDbusMonitor()
    monitor.start_monitoring()

    while True:
        proxy = monitor.get_current_proxy()
        url_check = make_url_checker(cfg, proxy)

        state = override_state_if_connman_properties_changed(cfg, state, monitor.last_update)

        debug(f"Current state: {state}")
        match state:
            case StateNeverConnected():
                state = run_state_never_connected(cfg, url_check)

            case StateOnceConnected(remain_attempts):
                state = run_state_once_connected(cfg, url_check, remain_attempts)

            case StateDisconnected():
                state = run_state_disconnected(cfg)

            case StateSettingChangeDelay(time_since_update, next_state):
                state = run_state_setting_change_delay(cfg, time_since_update, next_state)


def main():
    args = parse_args()
    if args.debug:
        logging.basicConfig(level=logging.DEBUG)
    else:
        logging.basicConfig(level=logging.INFO)

    run(args)


if __name__ == "__main__":
    main()
