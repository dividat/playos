import subprocess
import os
from PyQt5.QtNetwork import QNetworkProxy

def get_from_pacrunner():
    return subprocess.run(["pacproxy"], capture_output=True, text=True).stdout.rstrip()

def update_env(proxy):
    os.environ['http_proxy'] = proxy
    os.environ['https_proxy'] = proxy

def use_in_qt_app(proxy):
    if ":" in proxy:
        [proxy_host, proxy_port] = proxy.split(":")
    else:
        proxy_host = proxy
        proxy_port = None

    network_proxy = QNetworkProxy()
    network_proxy.setType(QNetworkProxy.HttpProxy)
    network_proxy.setHostName(proxy_host)
    if proxy_port != None:
        network_proxy.setPort(int(proxy_port))
    QNetworkProxy.setApplicationProxy(network_proxy)
