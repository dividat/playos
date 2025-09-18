import pytest
from PyQt6.QtCore import Qt, QEvent
from PyQt6.QtWidgets import QWidget, QApplication
from PyQt6.QtGui import QKeyEvent
from typing import List
import itertools

from kiosk_browser.focus_object_tracker import FocusObjectTracker
from kiosk_browser.long_press import LongPressEvents, KeyCombination

LONG_PRESS_DURATION_MS = 300
MULTI_KEY_DELAY_ERROR_MS = 30

COMBINATIONS = [
    KeyCombination(name='menu',              keys=frozenset({ Qt.Key.Key_Menu })),
    KeyCombination(name='escape',            keys=frozenset({ Qt.Key.Key_Escape })),
    KeyCombination(name='escape-down',       keys=frozenset({ Qt.Key.Key_Escape, Qt.Key.Key_Down })),
    KeyCombination(name='escape-left',       keys=frozenset({ Qt.Key.Key_Escape, Qt.Key.Key_Left })),
    KeyCombination(name='escape-left-right', keys=frozenset({ Qt.Key.Key_Escape, Qt.Key.Key_Left, Qt.Key.Key_Right })),
]

COMBO_PARAMS = [pytest.param(c, id=c.name) for c in COMBINATIONS]

AMBIGUOUS_COMBOS = [
    pytest.param(frozenset({ Qt.Key.Key_Menu, Qt.Key.Key_Escape }), id="menu-escape"),
    pytest.param(frozenset({ Qt.Key.Key_Escape, Qt.Key.Key_Down, Qt.Key.Key_Left }), id="escape-down-left"),
]

KEY_EVENTS = [ QEvent.Type.ShortcutOverride, QEvent.Type.KeyPress, QEvent.Type.KeyRelease ]

## Helper code for simulating long-presses

def keyEvent(eventType, key, isAutoRepeat):
    return QKeyEvent(eventType, key, Qt.KeyboardModifier.NoModifier, '', autorep=isAutoRepeat)

def shortcutOverrideEvent(key, isAutoRepeat=False):
    return keyEvent(QEvent.Type.ShortcutOverride, key, isAutoRepeat)

def keyPressEvent(key, isAutoRepeat=False):
    return keyEvent(QEvent.Type.KeyPress, key, isAutoRepeat)

def keyReleaseEvent(key, isAutoRepeat=False):
    return keyEvent(QEvent.Type.KeyRelease, key, isAutoRepeat)

def sendEvent(widget, event):
    # Using notify() instead of event() to ensure the event passes through the eventFilter
    QApplication.instance().notify(widget, event)

# QTest does not provide a way to produce isAutoRepeat key events. Also, the
# logic of what gets auto-repeated is specific to the platform. Here we simulate
# what X11 does.
def simulate_long_press(qtbot, widget, keys: List[Qt.Key], duration_ms=LONG_PRESS_DURATION_MS+40, repeat_interval_ms=20):
    assert duration_ms > repeat_interval_ms, "repeat_interval_ms must be smaller than duration_ms"

    # Initial press for all keys
    for key in keys:
        # Note: current implementation can work with one or both of the event types present
        sendEvent(widget, shortcutOverrideEvent(key))
        sendEvent(widget, keyPressEvent(key))

    # Produce isAutoRepeat events **for the first key only**
    # Note: on X11 it seems that only "regular" keys are repeated, e.g.
    # pressing down `q` and `w` will repeat both, while pressing down Esc+Left
    # will repeat only the Left. We arbitrarly pick the first key for
    # repetition, because the implementation should be agnostic to such X11
    # peculiarities.
    first_key = keys[0]
    while duration_ms > 0:
        qtbot.wait(repeat_interval_ms)
        duration_ms -= repeat_interval_ms

        # On X11 there's a KeyRelease for every KeyPress, but they are marked
        # with isAutoRepeat while the key is held, which is what we simulate
        sendEvent(widget, keyReleaseEvent(first_key, isAutoRepeat=True))
        sendEvent(widget, shortcutOverrideEvent(first_key, isAutoRepeat=True))
        sendEvent(widget, keyPressEvent(first_key, isAutoRepeat=True))

    for key in keys:
        # Final KeyRelease without isAutoRepeat
        sendEvent(widget, keyReleaseEvent(key))

## Helper asserts

def assert_key_events_were_filtered_out(events, combo_keys):
    combo_key_events = [ev for ev in events if ev.key() in combo_keys]
    first_nonrepeated = list(itertools.takewhile(lambda p: not p.isAutoRepeat(), combo_key_events))
    remaining_events = combo_key_events[len(first_nonrepeated):]

    # it's ok to pass thru the initial non-repeated ShortcutOverride or KeyPress events
    assert {ev.type() for ev in first_nonrepeated} <= {QEvent.Type.ShortcutOverride, QEvent.Type.KeyPress}

    # everything else should be filtered out
    assert len(remaining_events) == 0

## Helper fixtures/objects

class KeyLogger(QWidget):
    def __init__(self):
        super().__init__()
        self.received_key_events = []

    def reset(self):
        self.received_key_events = []

    def event(self, event):
        if event.type() in KEY_EVENTS:
            self.received_key_events.append(event)

        return super().event(event)


@pytest.fixture
def key_logger(qtbot) -> KeyLogger:
    widget = KeyLogger()
    qtbot.addWidget(widget)
    return widget


@pytest.fixture
def focus_object_tracker() -> FocusObjectTracker:
    return FocusObjectTracker()

@pytest.fixture
def long_press(key_logger: KeyLogger, focus_object_tracker: FocusObjectTracker) -> LongPressEvents:
    long_press = LongPressEvents(key_logger, COMBINATIONS,
                              focus_object_tracker,
                              long_press_delay=LONG_PRESS_DURATION_MS/1000,
                              combo_compensation=MULTI_KEY_DELAY_ERROR_MS/1000)
    # key_logger.setFocus does not work since there's no QWindow?
    focus_object_tracker.focusObjectChanged.emit(None, key_logger)
    return long_press


## Tests

@pytest.mark.parametrize("combo", COMBO_PARAMS)
def test_each_long_press(qtbot, combo, key_logger, long_press):
    with qtbot.waitSignal(long_press.long_press_combo, timeout=LONG_PRESS_DURATION_MS+100) as signal:
        simulate_long_press(qtbot, key_logger, list(combo.keys))

    assert signal.args == [combo.name]
    assert_key_events_were_filtered_out(key_logger.received_key_events, combo.keys)
    key_logger.reset()


@pytest.mark.parametrize("combo", COMBO_PARAMS)
def test_each_short_press(qtbot, combo, key_logger, long_press):
    with qtbot.assertNotEmitted(long_press.long_press_combo):
        simulate_long_press(qtbot, key_logger, list(combo.keys),
                            duration_ms=round(LONG_PRESS_DURATION_MS/2))

# testing to check if there's any state-reset issues
@pytest.mark.parametrize("combo", COMBO_PARAMS)
def test_each_both_press(qtbot, combo, key_logger, long_press):
    test_each_long_press(qtbot, combo, key_logger, long_press)
    test_each_short_press(qtbot, combo, key_logger, long_press)
    key_logger.reset()
    test_each_long_press(qtbot, combo, key_logger, long_press)

# also testing statefulness
def test_all_in_sequence(qtbot, key_logger, long_press):
    for combo in COMBINATIONS:
        test_each_long_press(qtbot, combo, key_logger, long_press)

@pytest.mark.parametrize("combo_keys", AMBIGUOUS_COMBOS)
def test_ambiguous_signals_are_not_emitted(qtbot, combo_keys, key_logger, long_press):
    with qtbot.assertNotEmitted(long_press.long_press_combo):
        simulate_long_press(qtbot, key_logger, list(combo_keys))


def test_partial_combo_keys_are_not_filtered_out(qtbot, key_logger, focus_object_tracker):
    qtbot.addWidget(key_logger)
    combo = KeyCombination(name='A-B', keys=frozenset({ Qt.Key.Key_A, Qt.Key.Key_B }))
    long_press = LongPressEvents(key_logger, [ combo ],
                              focus_object_tracker,
                              long_press_delay=LONG_PRESS_DURATION_MS/1000,
                              combo_compensation=MULTI_KEY_DELAY_ERROR_MS/1000)
    focus_object_tracker.focusObjectChanged.emit(None, key_logger)

    simulate_long_press(qtbot, key_logger, [ Qt.Key.Key_A ])

    def expected_key_event_types(key):
        return set(itertools.product([ key ], KEY_EVENTS, [True, False]))

    def received_key_event_types(events):
        return set([(ev.key(), ev.type(), ev.isAutoRepeat()) for ev in events if ev.key() != 0])

    assert received_key_event_types(key_logger.received_key_events) == expected_key_event_types(Qt.Key.Key_A)
    key_logger.reset()

    simulate_long_press(qtbot, key_logger, [ Qt.Key.Key_B ])

    assert received_key_event_types(key_logger.received_key_events) == expected_key_event_types(Qt.Key.Key_B)
    key_logger.reset()

    test_each_long_press(qtbot, combo, key_logger, long_press)
