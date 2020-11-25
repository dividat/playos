import subprocess
import logging
import urllib
from PyQt5.QtNetwork import QNetworkProxy

def get_from_connman():
    try:
        return subprocess.run(
            ["connman-manual-proxy"],
            capture_output=True,
            text=True
        ).stdout.rstrip()
    except FileNotFoundError as e:
        logging.error(f"connman-manual-proxy not found: {e}")
        return ""

def use_in_qt_app(proxy):
    """Use http proxy in Qt application"""
    url = urllib.parse.urlparse(proxy)

    if url.hostname != None and url.port != None:
      logging.info(f"Using http proxy {url.hostname}:{url.port}")

      network_proxy = QNetworkProxy()
      network_proxy.setType(QNetworkProxy.HttpProxy)

      network_proxy.setHostName(url.hostname)
      network_proxy.setPort(url.port)

      QNetworkProxy.setApplicationProxy(network_proxy)
