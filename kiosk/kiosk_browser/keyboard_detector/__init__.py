"""Keyboard detector module with platform-specific implementations."""

import os

# Conditionally import the appropriate implementation based on environment
if os.getenv("KIOSK_USE_MOCKS"):
    from .mocked import KeyboardDetector as KeyboardDetector  # type: ignore[assignment]
else:
    from .linux import KeyboardDetector as KeyboardDetector  # type: ignore[assignment]

__all__ = ["KeyboardDetector"]
