#!/usr/bin/env python3

import evdev
import logging
import subprocess
import sys
import threading

logging.basicConfig(level=logging.INFO)

def handle_device(device):
    """Handle power key presses for the given input device by invoking poweroff."""

    logging.info(f'Listening to Power Button on device {device.path}')
    try:
        for event in device.read_loop():
            if event.type == evdev.ecodes.EV_KEY and event.code == evdev.ecodes.KEY_POWER and event.value:
                logging.info(f'KEY_POWER detected on {device.path}, shutting down')
                subprocess.run(['systemctl', 'start', 'poweroff.target'], check=True)
    except Exception as e:
        logging.error(f'Error handling {device.path}: {e}')

def get_power_button_devices():
    """Get all input devices which identify as 'Power Button' and have a power key."""

    devices = [evdev.InputDevice(path) for path in evdev.list_devices()]

    power_button_devices = []
    for device in devices:
        try:
            if device.name == 'Power Button':
                ev_capabilities = device.capabilities().get(evdev.ecodes.EV_KEY, [])
                if evdev.ecodes.KEY_POWER in ev_capabilities:
                    power_button_devices.append(device)
        except Exception as e:
            logging.warning(f'Failed to inspect {device.path}: {e}')

    return power_button_devices

# Identify Power Button devices
power_button_devices = get_power_button_devices()
if not power_button_devices:
    logging.error('No Power Button devices found')
    sys.exit(1)
logging.info(f'Found {len(power_button_devices)} Power Button device(s)')

# Start a thread with a handler for each identified device
handler_threads = []
for device in power_button_devices:
    thread = threading.Thread(target=handle_device, args=(device,))
    thread.start()
    handler_threads.append(thread)

# Exit gracefully if a handler executes
try:
    for thread in handler_threads:
        thread.join()
except KeyboardInterrupt:
    sys.exit(0)

