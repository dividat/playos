"""Mock proxy module for non-Linux platforms or testing."""

import logging


class Proxy:
    """Mock implementation of Proxy for platforms without D-Bus/Connman."""

    def __init__(self):
        logging.info("Using mock proxy - proxy monitoring disabled")
        self._proxy = None

    def start_monitoring_daemon(self):
        """Mock implementation - does nothing."""
        pass

    def get_current(self):
        """Always returns None (no proxy)."""
        return None
