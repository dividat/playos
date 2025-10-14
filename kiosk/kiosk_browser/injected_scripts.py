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

class FocusShiftScript(KioskInjectedScript):
    def __init__(self):
        super().__init__("focusShift")
        self.setSourceUrl(QtCore.QUrl.fromLocalFile(assets.FOCUS_SHIFT_PATH))

class KeyboardDetectorBridge(KioskInjectedScript):
    def __init__(self):
        super().__init__("keyboardDetectorBridge")
        self.setWorldId(QWebEngineScript.ScriptWorldId.MainWorld)

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
const keyboard_available_handler = function (keyboard_available) {
    const event = new CustomEvent("KeyboardAvailableChanged", { detail: { keyboard_available: keyboard_available }});
    window.dispatchEvent(event);
}

window.onload = function () {
    new QWebChannel(qt.webChannelTransport, function(channel) {
        const keyboard_detector = channel.objects.keyboard_detector;

        keyboard_detector.keyboard_available_changed.connect(keyboard_available_handler);

        keyboard_available_handler(keyboard_detector.keyboard_available);
    });
}

/// DEMO USAGE
window.addEventListener("KeyboardAvailableChanged", (e) => {
    const keyboard_available = e.detail.keyboard_available;
    console.error("Got KeyboardAvailableChanged from Python, keyboard_available =", keyboard_available);

    let color = keyboard_available ? "blue" : "red";
    const css = `
      html body {
        background: ${color} !important;
      }
    `;
    const elem = document.createElement('style');
    elem.textContent = css;
    document.head.appendChild(elem);
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
const css = `
  html body *:focus-visible:focus-visible:focus-visible:focus-visible {
    outline: outset thick rgb(255 255 0 / 0.8) !important;
  }
`;

const elem = document.createElement('style');
elem.textContent = css;
document.head.appendChild(elem);
        """)
