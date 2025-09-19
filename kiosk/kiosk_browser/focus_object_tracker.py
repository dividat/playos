# Small helper for tracking the current Qt focusObject while avoiding
# pitfalls/bugs
from PyQt6 import QtCore, sip
from PyQt6.QtWidgets import QApplication

# The focusObjectChanged signal is an "enhanced" version of the
# QApplication.focusObjectChanged signal:
# 1) it provides a reference to the previous focusObject, which will be None if
#    it no longer exists (e.g. was GCed)
# 2) it ensures the current focusObject always matches QApplication.focusObject
class FocusObjectTracker(QtCore.QObject):
    focusObjectChanged = QtCore.pyqtSignal(QtCore.QObject, QtCore.QObject)

    def __init__(self, parent=None):
        super().__init__(parent)

        self._focus_object = None
        QApplication.instance().focusObjectChanged.connect(self._update_focus_object)

    def _update_focus_object(self, new_focus_object):
        old_focus_object = self._focus_object
        if self._focus_object is not None:
            # prevent crashes when underlying C++ object gets destroyed, but we
            # are still holding onto the reference
            if sip.isdeleted(self._focus_object):
                old_focus_object = None

        # Workaround to QTBUG-138256, see also patch in pkgs/qtvirtualkeyboard/
        if new_focus_object != QApplication.focusObject():
            new_focus_object = QApplication.focusObject()

        self._focus_object = new_focus_object

        self.focusObjectChanged.emit(old_focus_object, new_focus_object)
