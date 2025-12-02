"""Keyboard detector module with platform-specific implementations."""

import os
import sys

# Conditionally import the appropriate implementation based on environment
if os.getenv("KIOSK_USE_MOCKS") or sys.platform == "darwin":
    from .mocked import KeyboardDetector as KeyboardDetector  # type: ignore[assignment]
else:
    from .linux import KeyboardDetector as KeyboardDetector  # type: ignore[assignment]

__all__ = ["KeyboardDetector"]
