# PlayOS Kiosk Browser

Cycle between two urls in a full screen, locked down browser based on [QtWebEngine](http://doc.qt.io/qt-5/qtwebengine-index.html). Allow login to captive portals.

## Development

Run `nix-shell` to create a suitable development environment.

Then, start the kiosk browser with, for example:

```bash
bin/kiosk-browser http://localhost:8080/play.html http://localhost:3333
```

## Testing

        bin/test

## Developer tools

Run with `QTWEBENGINE_REMOTE_DEBUGGING` equals to a specific port:

```bash
QTWEBENGINE_REMOTE_DEBUGGING=3355 bin/kiosk-browser …
```

Then, point a Chromium-based browser to `http://127.0.0.1:3355`.

Additional documentation is available at:
https://doc.qt.io/qt-5/qtwebengine-debugging.html
