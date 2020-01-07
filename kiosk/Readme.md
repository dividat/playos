# PlayOS Kiosk Browser

Cycle between two urls in a full screen, locked down browser based on [QtWebEngine](http://doc.qt.io/qt-5/qtwebengine-index.html). Allow login to captive portals.

## Development

Run `nix-shell` to create a suitable development environment.

Then, start the kiosk browser with, for example:

```bash
bin/kiosk-browser http://localhost:8080/play.html http://localhost:3333
```
