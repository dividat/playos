from PyQt6 import QtCore
from PyQt6.QtWebEngineCore import QWebEngineScript

from kiosk_browser import assets

# base class for setup
class KioskInjectedScript(QWebEngineScript):
    def __init__(self, name):
        super().__init__()
        self.setName(name)
        self.setInjectionPoint(QWebEngineScript.InjectionPoint.DocumentReady)
        self.setRunsOnSubFrames(True) # TODO: ?
        self.setWorldId(QWebEngineScript.ScriptWorldId.ApplicationWorld)

class FocusShiftScript(KioskInjectedScript):
    def __init__(self):
        super().__init__("focusShift")
        self.setSourceUrl(QtCore.QUrl.fromLocalFile(assets.FOCUS_SHIFT_PATH))


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
