"""Mock proxy module for non-Linux platforms or testing."""

import logging
from typing import Optional


class ProxyConfig:
    """Simple proxy configuration."""

    def __init__(self, hostname: str, port: int):
        self.hostname = hostname
        self.port = port


class Proxy:
    def __init__(self):
        logging.info("Using mock proxy - proxy monitoring disabled")
        self._proxy = None
        # Check for override via environment variable
        import os

        override_proxy = os.getenv("KIOSK_PROXY_OVERRIDE")
        if override_proxy:
            try:
                # Parse format: hostname:port
                hostname, port = override_proxy.rsplit(":", 1)
                self._proxy = ProxyConfig(hostname, int(port))
                logging.info(f"Using proxy override: {hostname}:{port}")
            except Exception as e:
                logging.warning(f"Invalid proxy override format: {override_proxy}")

    def start_monitoring_daemon(self):
        """Use initial proxy in Qt application and watch for changes."""
        # Mock implementation - no monitoring needed
        if self._proxy:
            # Could apply proxy to Qt here if needed
            logging.debug(
                f"Mock proxy would apply: {self._proxy.hostname}:{self._proxy.port}"
            )
        pass

    def get_current(self):
        return self._proxy
