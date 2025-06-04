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
from typing import List

CLIENT_HEADERS = {'User-Agent': 'PlayOS watchdog 1.0'}
CONNMAN_RESTART_COMMAND = "systemctl restart connman.service"
CONNMAN_SIGNAL_IGNORELIST = [
    "Strength", # each wifi scan updates this
]

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


@dataclass
class URLCheckError:
    url: str
    reason: str

    def __str__(self):
        return f"URL check for {self.url} failed: {self.reason}"


# returned None signals success
def perform_single_url_check(url, timeout, proxy=None) -> None | URLCheckError:
    failure = None
    proxies = None
    if proxy:
        proxies = {
            'http': proxy.to_url(),
            'https': proxy.to_url()
        }

    try:
        r = requests.get(url,
                 headers=CLIENT_HEADERS, # identify ourselves to server
                 timeout=timeout,
                 stream=True, # avoid downloading the content, which we don't care about
                 allow_redirects=False, # we also don't care about response code
                 proxies=proxies)
        r.close()
    except Exception as e:
        failure = URLCheckError(url=url, reason=str(e))

    if failure:
        debug(failure)
    else:
        debug(f"URL check for {url} succeeded!")

    return failure


# returned None signals success
def perform_url_checks(urls, timeout, proxy: proxy_utils.ProxyConf | None) -> None | List[URLCheckError]:
    url_queue = deque(urls)
    errs = []
    while url_queue:
        next_url = url_queue.popleft()
        err = perform_single_url_check(next_url, timeout, proxy=proxy)

        if err is None:
            return None
        else:
            errs.append(err)
            continue

    return errs


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
    remaining_delay: datetime.timedelta
    next_state: State
    def __str__(self):
        return StateNames.SETTING_CHANGE_DELAY

State = StateNeverConnected | StateOnceConnected | StateDisconnected | StateSettingChangeDelay

## State actions

def run_state_never_connected(cfg, url_check) -> State:
    err = url_check()
    if err is not None:
        log(f"Check URL failed for all URLs, sleeping for {cfg.check_interval} seconds")
        check_sleep(cfg)
        return StateNeverConnected()
    else:
        log("Detected a working internet connection!")
        return StateOnceConnected(cfg.max_num_failures)


def run_state_once_connected(cfg, url_check, remain_attempts) -> State:
    err = url_check()
    if err is not None:
        remain_attempts -= 1
        if remain_attempts > 0:
            log(f"Check URLs failed, remaining attempts: {remain_attempts}")
            check_sleep(cfg)
            return StateOnceConnected(remain_attempts)

        else:
            errs_brief = "\n".join([f"- {e.url}: {e.reason}" for e in err])
            log(f"Check URLs failed {cfg.max_num_failures} times, internet connection considered lost.")
            log(f"Errors from last check:\n{errs_brief}")
            return StateDisconnected()

    else:
        debug("Check URL successful.")
        check_sleep(cfg)
        return StateOnceConnected(cfg.max_num_failures)



def run_state_disconnected(cfg) -> State:
    log("Restarting connman")
    subprocess.run(CONNMAN_RESTART_COMMAND, shell=True, check=False)

    return StateNeverConnected()


def run_state_setting_change_delay(cfg, remaining_delay, next_state: State) -> State:
    sleep_seconds = math.ceil(remaining_delay)
    log(f"Sleeping for {sleep_seconds} seconds after connman setting changes")
    time.sleep(sleep_seconds)
    return next_state

## Connman monitor

@dataclass(frozen=True)
class ConnmanServicePropertyChangedEvent:
    time: datetime.datetime
    property: str
    value: str
    service: str


class ConnmanDbusMonitor:
    def __init__(self):
        DBusGMainLoop(set_as_default=True)
        self._bus = dbus.SystemBus()
        self._thread = None
        self.last_update = ConnmanServicePropertyChangedEvent(
            time = datetime.datetime.fromtimestamp(0),
            property = "",
            service = "",
            value = ""
        )


    def start_monitoring(self):
        def monitor():
            debug("Starting DBus monitoring thread")

            self._bus.add_signal_receiver(
                handler_function=self._mark_update,
                bus_name='net.connman',
                dbus_interface='net.connman.Service',
                signal_name='PropertyChanged',
                path_keyword='path',
            )
            loop = GLib.MainLoop()
            loop.run()

        thread = threading.Thread(target=monitor)
        thread.daemon = True
        thread.start()
        self._thread = thread

    def _mark_update(self, name, value, path=None):
        if name in CONNMAN_SIGNAL_IGNORELIST:
            debug(f"Ignoring connman setting ({name}) update for path ({path})")
        else:
            debug(f"connman setting ({name}) change for ({path})")
            self.last_update = ConnmanServicePropertyChangedEvent(
                time = datetime.datetime.now(),
                property = str(name),
                service = str(path),
                value = str(value)
            )

    def get_current_proxy(self):
        return proxy_utils.get_current_proxy(self._bus)


def make_url_checker(cfg, proxy: None | proxy_utils.ProxyConf):
    return lambda: perform_url_checks(cfg.check_urls, cfg.check_url_timeout, proxy)


def override_state_if_connman_properties_changed(
        cfg,
        current_state: State,
        last_update: ConnmanServicePropertyChangedEvent) -> State:

    time_since_update = datetime.datetime.now() - last_update.time
    remaining_delay = cfg.setting_change_delay - time_since_update.total_seconds()

    if remaining_delay > 0:
        # override state, because there are recent connman changes
        log("Connman service properties changed recently, overriding current state.\n" + \
           f"Last property changed: {last_update.property} for {last_update.service}")
        return StateSettingChangeDelay(remaining_delay, next_state=current_state)
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

            case StateSettingChangeDelay(remaining_delay, next_state):
                state = run_state_setting_change_delay(cfg, remaining_delay, next_state)


def main():
    args = parse_args()
    logging.basicConfig(level=logging.INFO)
    if args.debug:
        logger.setLevel(logging.DEBUG)

    run(args)


if __name__ == "__main__":
    main()
