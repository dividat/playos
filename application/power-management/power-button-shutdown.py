#!/usr/bin/env python3

import evdev
import logging
import os
import sys

logging.basicConfig(level=logging.INFO)

devices = [evdev.InputDevice(path) for path in evdev.list_devices()]
device_names = ', '.join([d.name for d in devices])
logging.info(f'Found devices: {device_names}')

power_off_device = next((d for d in devices if d.name == 'Power Button'), None)
if power_off_device is None:
  logging.error(f'Power Button device not found')
  sys.exit(1)

logging.info(f'Listenning to Power Button on device {power_off_device.path}')
for event in power_off_device.read_loop():
  if event.type == evdev.ecodes.EV_KEY and evdev.ecodes.KEY[event.code] == 'KEY_POWER' and event.value:
    logging.info('KEY_POWER detected on Power Button device, shutting down')
    os.system('systemctl start poweroff.target')
