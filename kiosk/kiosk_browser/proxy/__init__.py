"""Proxy module with platform-specific implementations."""

import os

# Conditionally import the appropriate implementation based on environment
if os.getenv("KIOSK_USE_MOCKS"):
    from .mocked import Proxy as Proxy  # type: ignore[assignment]
else:
    from .linux import Proxy as Proxy  # type: ignore[assignment]

__all__ = ["Proxy"]
