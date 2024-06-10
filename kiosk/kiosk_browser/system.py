from dataclasses import dataclass
from kiosk_browser.proxy import Proxy
import platform

@dataclass 
class System:
    name: str = "@system_name@"
    version: str = "@system_version@"


def infer() -> tuple[System, Proxy]:
    if platform.system() in ['Darwin']:
        from kiosk_browser.proxy import Proxy
        import os
        return (System(name = "PlayOS",
                       version = os.getenv("PLAYOS_VERSION","1.0.0-dev")),
                Proxy())
    else:
        from kiosk_browser.dbus_proxy import DBusProxy
        return (System(), DBusProxy())




