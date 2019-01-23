# PlayOS Kiosk Browser

Opens a website in a full screen, locked down browser based on [QtWebView](http://doc.qt.io/qt-5/qtwebview-index.html).

## Usage
```
usage: PRIMARY_URL=foo SECONDARY_URL=baz kiosk-browser

Open two toggable websites in kiosk mode.

optional arguments:
  -h, --help            show this help message and exit
  --togglekey TOGGLEKEY
                        Keyboard combination to toggle between websites.
                        (Default: "CTRL+SHIFT+F12")

Additional browser debugging environment variables can be found under
https://doc.qt.io/qt-5/qtwebengine-debugging.html
```
