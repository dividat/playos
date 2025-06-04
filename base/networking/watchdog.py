import argparse
import requests
import enum
from enum import auto
import time
import subprocess

CLIENT_HEADERS = {'User-Agent': 'PlayOS watchdog'}
CONNMAN_RESTART_COMMAND = "systemctl restart connman.service"


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check-url', required=True)
    parser.add_argument('--alt-check-url')
    parser.add_argument('--check-interval', type=int)
    parser.add_argument('--max-num-failures', type=int)
    return parser.parse_args()


class State(enum.StrEnum):
    INIT = auto()
    ONCE_CONNECTED = auto()
    PROBABLY_DISCONNECTED = auto()
    DISCONNECTED = auto()


# Returns None if successful or error message if failed
def perform_check(url):
    # TODO: lookup proxy in connman if configured
    failure = None
    try:
        # stream=True avoids downloading the content, which we don't care about
        r = requests.get(url, headers=CLIENT_HEADERS, stream=True, allow_redirects=True)
        if r.status_code != 200:
            failure = f"Bad HTTP status code: {r.status_code}"
    except Exception as e:
        failure = f"Failed to connect: {e}"

    return failure


def sleep(cfg):
    time.sleep(cfg.check_interval)


def run_state_init(cfg) -> State:
    connected = False

    while not connected:
        err = perform_check(cfg.check_url)
        if err:
            print(f"Check URL failed: {err}, sleeping for {cfg.check_interval} seconds")
            sleep(cfg)
        else:
            print(f"Detected successful connection to {cfg.check_url}")
            connected = True

    return State.ONCE_CONNECTED


def run_state_once_connected(cfg) -> State:
    remain_failures = cfg.max_num_failures
    while remain_failures > 0:
        sleep(cfg)
        err = perform_check(cfg.check_url)
        if err:
            print(f"Check URL failed: {err}")
            remain_failures -= 1
        else:
            print("Check URL successful")
            remain_failures = cfg.max_num_failures

    return State.PROBABLY_DISCONNECTED


def run_state_probably_disconnected(cfg) -> State:
    if cfg.alt_check_url:
        err = perform_check(cfg.alt_check_url)
        if err:
            print(f"Check for alt URL failed: {err}, internet connection lost.")
            return State.DISCONNECTED
        else:
            return State.ONCE_CONNECTED
    else:
        return State.DISCONNECTED


def run_state_disconnected(cfg) -> State:
    subprocess.run(CONNMAN_RESTART_COMMAND, shell=True, check=False)

    return State.INIT


def run(cfg):
    state = State.INIT

    while True:
        print(f"Watchdog state: {state}")
        match state:
            case State.INIT:
                state = run_state_init(cfg)

            case State.ONCE_CONNECTED:
                state = run_state_once_connected(cfg)

            case State.PROBABLY_DISCONNECTED:
                state = run_state_probably_disconnected(cfg)

            case State.DISCONNECTED:
                state = run_state_disconnected(cfg)


def main():
    args = parse_args()
    run(args)


if __name__ == "__main__":
    main()
