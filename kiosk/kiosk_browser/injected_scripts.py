from PyQt6 import QtCore
from PyQt6.QtWebEngineCore import QWebEngineScript

from kiosk_browser import assets

# base class for setup
class KioskInjectedScript(QWebEngineScript):
    def __init__(self, name):
        super().__init__()
        self.setName(name)
        self.setInjectionPoint(QWebEngineScript.InjectionPoint.DocumentReady)
        self.setRunsOnSubFrames(True)
        self.setWorldId(QWebEngineScript.ScriptWorldId.ApplicationWorld)

    def setSourceCode(self, source_code):
        # avoid polluting the global scope
        local_scoped_src = '(function () {\n\n' + source_code + '\n\n})();'
        super().setSourceCode(local_scoped_src)

class FocusShiftScript(KioskInjectedScript):
    def __init__(self):
        super().__init__("focusShift")
        # worldId must match FocusShiftBridge.worldId!
        self.setWorldId(QWebEngineScript.ScriptWorldId.MainWorld)
        with open(assets.FOCUS_SHIFT_PATH, "r") as f:
            self.setSourceCode(f.read())


class FocusShiftBridge(KioskInjectedScript):
    def __init__(self):
        super().__init__("FocusShiftBridge")
        # Needs to run on MainWorld to be able to interact with focus-shift on Play
        # and to expose events to page scripts.
        self.setWorldId(QWebEngineScript.ScriptWorldId.MainWorld)
        # qt.webChannelTransport is not available on iframes
        self.setRunsOnSubFrames(False)

        # provided by QWebChannel
        qwebchannel_js = QtCore.QFile(':/qtwebchannel/qwebchannel.js')
        if not qwebchannel_js.open(QtCore.QIODeviceBase.OpenModeFlag.ReadOnly):
            raise RuntimeError('Failed to load qwebchannel.js: %s' % qwebchannel_js.errorString())
        qwebchannel_js = bytes(qwebchannel_js.readAll()).decode('utf-8')
        libJsStr = f"""
/// qwebchannel.js
{qwebchannel_js}
"""

        clientJs = """
window.addEventListener("load", () => {
    function dispatchKeyboardAvailabilityChange(hasPhysicalKeyboard) {
        window.dispatchEvent(new CustomEvent(
            "kiosk:keyboardavailabilitychange",
            { detail: { hasPhysicalKeyboard }, bubbles: false, cancelable: false}
        ));
    }

    new QWebChannel(qt.webChannelTransport, (channel) => {
        const keyboard_detector = channel.objects.keyboard_detector;

        keyboard_detector.keyboard_available_changed.connect(dispatchKeyboardAvailabilityChange);

        dispatchKeyboardAvailabilityChange(keyboard_detector.keyboard_available);

        window.addEventListener("focus-shift:exhausted", (event) => {
            channel.objects.focus_transfer.reached_end(event.detail.direction);
        });
    });

});

window.addEventListener("kiosk:keyboardavailabilitychange", (event) => {
    document.documentElement.style.setProperty(
        "--focus-interaction-behavior",
        event.detail.hasPhysicalKeyboard ? "normal" : "opaque"
    );
});
"""
        self.setSourceCode(libJsStr + clientJs)


class EnableInputToggleWithEnterScript(KioskInjectedScript):
    def __init__(self):
        super().__init__("inputToggleWithEnter")
        self.setSourceCode("""
// simplified version of SpatialNavigation.ts in diviapps
document.addEventListener('keydown', (event) => {
    if (event.key === 'Enter') {
        performSyntheticClick(event)
    }
})
function performSyntheticClick(event) {
    const activeElement = document.activeElement
    if (
        activeElement instanceof HTMLInputElement &&
        (activeElement.type === 'checkbox' || activeElement.type === 'radio')
    ) {
        activeElement.click()
        event.preventDefault()
    }
}
        """)


# Note: on pages with Content-Security-Policy enabled for styles (`style-src
# 'self'`), this will fail with "Refused to apply inline style because it
# violates the following Content Security Policy directive <..>".
# There is no alternative for injecting CSS or overriding CSP in qtwebengine (as
# of 6.9.2) and this is not major issue, so we keep it as is. A last-resort
# workaround could be to launch a proxy that removes CSP headers from responses.
class ForceFocusedElementHighlightingScript(KioskInjectedScript):
    def __init__(self):
        super().__init__("ForceFocusedElementHighlightingScript")
        self.setSourceCode("""
window.addEventListener("load", () => {
    const css = `
      html body *:focus-visible:focus-visible:focus-visible:focus-visible {
        outline: outset thick rgb(255 255 0 / 0.8) !important;
      }
    `;

    const elem = document.createElement('style');
    elem.textContent = css;
    document.head.appendChild(elem);
});
        """)
