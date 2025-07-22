# PlayOS Kiosk Browser

Cycle between two urls in a full screen, locked down browser based on [QtWebEngine](https://doc.qt.io/qt-6/qtwebengine-index.html). Allow login to captive portals.

## Development

Run `nix-shell` to create a suitable development environment.

Then, start the kiosk browser with, for example:

```bash
bin/kiosk-browser http://localhost:8080/play.html http://localhost:3333
```

If running on non-nixOS systems, you might need the
[nixGL](https://github.com/nix-community/nixGL) wrapper to ensure OpenGL works.
See https://github.com/NixOS/nixpkgs/issues/9415 for context.

## Testing

        bin/test

## Developer tools

Run with `QTWEBENGINE_REMOTE_DEBUGGING` equals to a specific port:

```bash
QTWEBENGINE_REMOTE_DEBUGGING=3355 bin/kiosk-browser …
```

Then, point a Chromium-based browser to `http://127.0.0.1:3355`.

Additional documentation is available at:
https://doc.qt.io/qt-6/qtwebengine-debugging.html
