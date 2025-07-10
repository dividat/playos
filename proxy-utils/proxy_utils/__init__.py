"""
This module contains helpers for obtaining the currently configured proxy
from connman service properties via DBus.

The main entrypoint is `get_current_proxy`. The caller is expected
to set up a DBus system session, see `kiosk_browser/proxy.py` or `wachdog.py` for
examples.
"""
from urllib.parse import quote, unquote, urlparse
import dbus # type: ignore
import logging
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

    def to_url(self) -> str:
        domain = f'{self.hostname}:{self.port}'
        if self.credentials:
            credential_str = f'{quote(self.credentials.username)}:{quote(self.credentials.password)}'
            return f'http://{credential_str}@{domain}'
        else:
            return f'http://{domain}'



@dataclass
class Service:
    state: str
    proxy: ProxyConf | None

def parse_service(service: dbus.Struct) -> Service | None:
    if len(service) >= 2 and 'State' in service[1]:
        return Service(service[1]['State'], extract_manual_proxy(service[1]))
    else:
        return None

def extract_manual_proxy(service_conf: dbus.Dictionary) -> ProxyConf | None:
    if 'Proxy' in service_conf:
        proxy = service_conf['Proxy']
        if 'Method' in proxy and 'Servers' in proxy:
            method = proxy['Method']
            servers = proxy['Servers']
            if method == 'manual' and len(servers) >= 1:
                return parse_proxy_url(servers[0])
            else:
                return None
        else:
            return None
    else:
        return None

def parse_proxy_url(url: str) -> ProxyConf | None:
    if url.startswith('http://'):
        parsed = urlparse(url)
    else:
        parsed = urlparse(f'http://{url}')

    if parsed.hostname != None and parsed.port != None:
        assert isinstance(parsed.hostname, str)
        assert isinstance(parsed.port, int)

        if parsed.username != None and parsed.password != None:
            assert isinstance(parsed.username, str)
            assert isinstance(parsed.password, str)

            username = unquote(parsed.username)
            password = unquote(parsed.password)
            return ProxyConf(parsed.hostname, parsed.port, Credentials(username, password))
        else:
            return ProxyConf(parsed.hostname, parsed.port, None)
    else:
        logging.warning("Hostname or port missing in proxy url")
        return None

def get_current_proxy(bus) -> ProxyConf | None:
    """Get current proxy from dbus.

    Return the proxy of a connected service preferentially, or of a ready
    service.

    Return None if Connman is not installed (DBusException).
    """

    try:
        client = dbus.Interface(
            bus.get_object('net.connman', '/'),
            'net.connman.Manager')

        # List services, each service is a (id, properties) struct
        services = [parse_service(s) for s in client.GetServices()]

        # The service with the default route will always be sorted at the top of
        # the list. (From connman doc/overview-api.txt)
        default_service = find(lambda s: s.state in ['online', 'ready'], services)

        if default_service:
            return default_service.proxy
        else:
            return None

    except dbus.exceptions.DBusException:
        return None

def find(f, xs):
    return next((x for x in xs if f(x)), None)
