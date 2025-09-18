from PyQt6 import QtCore
from PyQt6.QtCore import Qt, QEvent
import time

from typing import List, NamedTuple
from functools import reduce

# how long a key needs to be held to be considered a long press
LONG_PRESS_DELAY_SECONDS = 1
# When multiple keys are pressed, they will be held down for slightly different
# durations. When detecting a combo, we require only the first key to be held
# for LONG_PRESS_DELAY_SECONDS, while other keys can be held for "only"
# LONG_PRESS_DELAY_SECONDS - MULTI_KEY_DELAY_ERROR_SECONDS
MULTI_KEY_DELAY_ERROR_SECONDS = 0.2


class KeyCombination(NamedTuple):
    name: str
    keys: frozenset[Qt.Key]


# Helper class that tracks long presses of single keys or key combinations.
#
# Triggered combination names are emitted via the long_press_combo signal.
#
# If combinations overlap, when a user holds down a key combination, the
# longest combination which is a subset of the keys held down is emitted.
#
# If the longest combination is not unique in length, no long_press_combo signal
# is emitted and state is reset.
#
# Example: if there are combinations for Menu, Menu+Left and Menu+Right
# configured, then if the user long-presses:
# - Menu+Left+Right - no long_press_combo signal emitted, since two combinations
#                     of equal length match the pressed keys
# - Menu+Left+Down - Menu+Left is emitted, because it is the (unique) longest
#                    matching sub-set
#
# The implementation installs an eventFilter to the passed parent object.
# It is recommended to the top-level QApplication as the parent instance, to
# ensure no other QObject's are able to intercept/handle the key events.
class LongPressEvents(QtCore.QObject):
    # only the combination name is emitted
    long_press_combo = QtCore.pyqtSignal(str)

    def __init__(self, parent, combinations: List[KeyCombination],
                 long_press_delay=LONG_PRESS_DELAY_SECONDS,
                 combo_compensation=MULTI_KEY_DELAY_ERROR_SECONDS):
        super().__init__(parent)

        # Configuration
        self._long_press_delay_seconds = long_press_delay
        self._combo_compensation_secons = combo_compensation

        # Helpers/Derived mmutable data
        self._tracked_combinations = combinations
        self._tracked_keys = reduce(frozenset.union, [c.keys for c in combinations])

        self._key_to_combos: dict[Qt.Key, List[KeyCombination]] = { k: [] for k in self._tracked_keys }
        for combo in combinations:
            for key in combo.keys:
                self._key_to_combos[key].append(combo)

        # State
        self._key_pressed_since: dict[Qt.Key, float] = {}
        self._supress_next_key_events: set[Qt.Key] = set()

        # Init
        parent.installEventFilter(self)

    def _key_is_long_pressed(self, key, err_tolerance=0.0):
        now = time.time()
        pressed_since = self._key_pressed_since.get(key, now)
        return now - pressed_since >  self._long_press_delay_seconds - err_tolerance

    def _combo_is_long_pressed(self, combo: KeyCombination):
        return all(map(
            lambda key: self._key_is_long_pressed(key, err_tolerance=self._combo_compensation_secons),
            combo.keys
        ))


    # indicates that all the keys are pressed down, regardless of duration
    def _combo_keys_pressed_down(self, combo):
        return all([key in self._key_pressed_since for key in combo.keys])

    # combos for which all the keys are pressed down, regardless of duration
    def _pressed_down_combos(self):
        return [combo for combo in self._tracked_combinations if self._combo_keys_pressed_down(combo)]

    def _active_combos(self):
        return [combo for combo in self._tracked_combinations if self._combo_is_long_pressed(combo)]

    def _key_is_part_of_pressed_down_combo(self, key):
        return any([key in combo.keys for combo in self._pressed_down_combos()])

    def _key_event_should_be_supressed(self, event: QEvent.Type.KeyPress | QEvent.Type.KeyRelease | QEvent.Type.ShortcutOverride):
        key = event.key()

        if key not in self._tracked_keys:
            return False

        supress_if_repeated = event.isAutoRepeat() and self._key_is_part_of_pressed_down_combo(key)
        supress_explicit = key in self._supress_next_key_events
        return supress_if_repeated or supress_explicit


    # Note: when this is installed on QApplication.instance(), it will receive
    # the same event multiple times as they traverse the widget tree, unless
    # this filters them out.
    def eventFilter(self, source, event):
        if event.type() == QtCore.QEvent.Type.ShortcutOverride:
            key = event.key()
            if key in self._tracked_keys:
                if not event.isAutoRepeat():
                    # first key press
                    self._key_pressed_since[key] = time.time()
                else:
                    if self._key_is_long_pressed(key):
                        long_pressed_combos = self._active_combos()
                        key_combos = self._key_to_combos[key]
                        long_pressed_key_combos = set(long_pressed_combos) & set(key_combos)
                        if len(long_pressed_key_combos) > 0:
                            longest_combo = sorted(list(long_pressed_key_combos),
                                                   key=lambda c: len(c.keys) * -1)[0]
                            # Check if longest combo is unique in length
                            same_length_active_combos = \
                                [c for c in long_pressed_combos if len(c.keys) == len(longest_combo.keys)]
                            # unset all key states, we don't want partial combos to become full combos
                            self._key_pressed_since = {}

                            if len(same_length_active_combos) == 1:
                                self.long_press_combo.emit(longest_combo.name)
                                # supress emitted combo key releases to prevent other handling
                                self._supress_next_key_events = set(longest_combo.keys)

                    return self._key_event_should_be_supressed(event)


        elif event.type() == QtCore.QEvent.Type.KeyPress:
            return self._key_event_should_be_supressed(event)

        elif event.type() == QtCore.QEvent.Type.KeyRelease:
            key = event.key()

            should_supress = self._key_event_should_be_supressed(event)

            if key in self._tracked_keys and not event.isAutoRepeat():
                self._key_pressed_since.pop(key, None)
                self._supress_next_key_events.discard(key)

            return should_supress

        return False

