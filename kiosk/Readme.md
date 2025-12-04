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

You can pass `--no-fullscreen` to run the kiosk windowed.

## macOS Development

When running on macOS, the kiosk browser automatically uses mocked implementations for:
- **Keyboard detection**: Reports no physical keyboard by default (enabling the virtual keyboard), but can be overridden with `KIOSK_MOCK_DISABLE_VKB=1` to simulate a keyboard being present
- **Proxy monitoring**: Proxy configuration monitoring is disabled (no D-Bus/Connman on macOS)

This allows development and testing on macOS without requiring Linux-specific dependencies like `evdev`, `pyudev`, or D-Bus.

You can also force the use of mocked implementations on Linux by setting the `KIOSK_USE_MOCKS` environment variable:

```bash
KIOSK_USE_MOCKS=1 bin/kiosk-browser ...
```

## Virtual keyboard

To "force" the virtual keyboard, you need to disable physical keyboard
detection, by setting the `PLAYOS_KEYBOARD_BLACKLIST` to wildcard:

```
PLAYOS_KEYBOARD_BLACKLIST=".*" bin/kiosk-browser ...
```

You can also use the env variable to selectively blacklist devices by name for
testing dynamic keyboard detection, see
[kiosk_browser/keyboard_detector/linux.py](kiosk_browser/keyboard_detector/linux.py) for
more details.


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
