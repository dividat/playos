import pytest

from kiosk_browser.browser_widget import TimerWithTicks


@pytest.fixture
def timer(qtbot):
    t = TimerWithTicks()
    yield t
    if t.isActive():
        t.stop()


class TestTimerWithTicks:
    def test_3_ticks(self, qtbot, timer):
        expected_signals = [
            (timer.tick, 300),
            (timer.tick, 200),
            (timer.tick, 100),
            (timer.timeout, None)
        ]
        expected_signal_types = [s[0] for s in expected_signals]
        expected_signal_values = [s[1] for s in expected_signals]

        with qtbot.waitSignals(expected_signal_types, order="strict", timeout=400) as signals:
            timer.start(100, 3)
            assert timer.isActive()

        assert [s.args[0] if s.args else None for s in signals.all_signals_and_args] == expected_signal_values

        assert not timer.isActive()

    def test_stop(self, qtbot, timer):
        with qtbot.waitSignal(timer.tick, timeout=30) as signal:
            timer.start(100, 5)
        assert signal.args == [100 * 5]

        with qtbot.assertNotEmitted(timer.timeout, wait=200):
            timer.stop()
        assert not timer.isActive()

    def test_restart_timer_resets_state(self, qtbot, timer):
        with qtbot.waitSignal(timer.timeout, timeout=300):
            timer.start(50, 2)

        self.test_3_ticks(qtbot, timer)
