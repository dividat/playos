import evdev
import pyudev
import logging
import time
import os
import re
from PyQt6.QtCore import QObject, pyqtSignal
from typing import NamedTuple, Optional


# For testing purposes: blacklist devices from being considered a keyboard.
# semicolon separated list of regex'es used to match evdev.InputDevice.name`s.
#
# Setting KEYBOARD_BLACKLIST=".*" is a way to disable detection entirely
KEYBOARD_BLACKLIST = [n.strip() for n in os.getenv("PLAYOS_KEYBOARD_BLACKLIST", "").split(";") if n.strip()]

class RemoteControlDevice(NamedTuple):
    # USB device vendor ID
    vendor: int
    # USB device product ID
    product: int
    name: str


# Remote controls currently circulating in the wild.
# The name is used for:
#   1) documentation purposes;
#   2) "fallback" matching in case the vendor/product IDs change (e.g. like with HAOBO).
REMOTE_CONTROLS = frozenset({
    # DT-007c, the "main" HAOBO RC, with the hole at bottom
    RemoteControlDevice(name = 'HAOBO Technology USB Composite Device Keyboard', vendor = 18498, product = 1),
    # ???????, another HAOBO prototype, unclear which
    RemoteControlDevice(name = 'HAOBO Technology USB Composite Device Keyboard', vendor = 3136,  product = 31260),
    # DT-009B, prototype with red Windows button on top
    RemoteControlDevice(name = 'MEMS TECH Keyboard',                             vendor = 7511,  product = 44291),
    # ???????, prototype with red power button and "mouse mode"
    RemoteControlDevice(name = '000001 KbMouse System Control',                  vendor = 9354,  product = 5774),
    # ???????, prototype with keyboard at the back.
    # Name is also 'MemsArt MA144 RF Controller Consumer Control', same IDs
    RemoteControlDevice(name = 'MemsArt MA144 RF Controller',                    vendor = 3141,  product = 20737)
})


def device_is_blacklisted(device: evdev.InputDevice) -> bool:
    return any([re.match(regex, device.name) for regex in KEYBOARD_BLACKLIST])


def input_device_matches_remote_control(device: evdev.InputDevice, remote_control: RemoteControlDevice) -> bool:
    info = device.info
    info_matches = info.vendor == remote_control.vendor and info.product == remote_control.product
    name_matches = device.name == remote_control.name
    return info_matches or name_matches


def find_matching_remote_control(device) -> Optional[RemoteControlDevice]:
    return next((rc for rc in REMOTE_CONTROLS if input_device_matches_remote_control(device, rc)), None)


# Keyboard identification is very heuristic since input devices often use
# generic drivers, which means they advertise EV_KEY's that are not physically
# present.
#
# We must therefore be conservative about labeling something as a keyboard to
# prevent false positives that lead to disabling the virtual keyboard. E.g. my
# Logitech mouse advertises 171 EV_KEY`s, most of which are obscure actions like
# KEY_VOICEMAIL.
#
# To do so, we look at the first 68 EV_KEY codes which define the most common keys
# and expect at least 60 of them to be defined. We also explicitly exclude the
# remote control device. Since we don't expect random input devices to be
# plugged in, it should mostly work.
def device_is_a_keyboard(device: evdev.InputDevice) -> bool:
    if rc := find_matching_remote_control(device):
        logging.debug(f"Input device {device.name} ({device.path}) matches remote control {rc.name}"
                      f" (vendor={rc.vendor}, product={rc.product}), not considering as a keyboard")
        return False

    max_relevant_keycode = 68
    # not likely to happen in a thousand years, mostly for clarity:
    assert evdev.ecodes.KEY_F10 == max_relevant_keycode, "key enumeration changed, review this!"

    all_ev_keys = device.capabilities().get(evdev.ecodes.EV_KEY, [])

    relevant_ev_keys = [k for k in all_ev_keys if k <= max_relevant_keycode]

    return len(relevant_ev_keys) > 60


def find_keyboard_devices() -> evdev.InputDevice:
    devices = list(map(evdev.InputDevice, evdev.list_devices()))
    # even if nothing is plugged in, there should be at least a power button here!
    if len(devices) == 0:
        logging.error("No input devices found, is the current user in the `input` group?")

    return [d for d in devices if device_is_a_keyboard(d) and not device_is_blacklisted(d)]


class KeyboardDetector(QObject):
    # Note: cannot use the callback directly, because the monitor is run in a
    # different thread. So instead we introduce a Qt signal.
    keyboard_available_changed = pyqtSignal(bool)

    def __init__(self, parent):
        super().__init__(parent)

        self.keyboard_available = None

        context = pyudev.Context()
        self._monitor = pyudev.Monitor.from_netlink(context)
        self._monitor.filter_by(subsystem='input')

        # fake call to set up the initial state
        self._observer_callback(None, None, sleep=False)
        self._observer = pyudev.MonitorObserver(self._monitor, self._observer_callback)
        self._observer.start()

    def _observer_callback(self, _action, _dev, sleep=True):
        if sleep:
            time.sleep(1)

        keyboards = find_keyboard_devices()

        keyboard_available = len(keyboards) > 0

        if self.keyboard_available != keyboard_available:
            # status change
            self.keyboard_available = keyboard_available
            self.keyboard_available_changed.emit(self.keyboard_available)

            if self.keyboard_available:
                logging.info(f"Detected keyboard devices: {", ".join([k.name for k in keyboards])}")
            else:
                logging.info("All keyboard devices disconnected.")
