from dataclasses import dataclass


@dataclass
class Credentials:
    username: str
    password: str

@dataclass
class ProxyConf:
    hostname: str
    port: int
    credentials: Credentials | None

class Proxy:
    """Base class for proxy querying.

    The base class does not know how to query for proxy information and may be used as a fallback that always reports that no proxy is configured.
    """
    _proxy: ProxyConf | None = None

    # For the base class, this is a pass, not knowing how to monitor in the general case.
    def start_monitoring_daemon(self) -> None:
        """Start a daemon monitoring for proxy changes.

        In the base class, no monitoring method is known, and starting a daemon is skipped.
        """
        pass

    def get_current(self) -> ProxyConf | None:
        """Get the currently configured proxy.

        This is always `None` in the base class.
        """
        return self._proxy
