from PyQt6 import QtWidgets, QtCore, QtGui
from PyQt6.QtCore import Qt


class Button(QtWidgets.QPushButton):
    def __init__(self, label, primary_color, parent):
        super().__init__(label, parent)

        r, g, b = primary_color

        self.setCursor(QtGui.QCursor(QtCore.Qt.CursorShape.PointingHandCursor))
        self.setStyleSheet(f"""
            QPushButton {{
                background-color: rgba({r}, {g}, {b}, 0.7);
                border: 0;
                color: white;
                font-weight: bold;
                padding: 5px 15px;
            }}
            :hover, :focus {{
                background-color: rgba({r}, {g}, {b}, 0.8);
                border: 3px solid #e0cb52;
                padding: 2px 12x;
            }}
        """)


    def keyPressEvent(self, event):
        Key = Qt.Key
        # Disable default handling of arrow keys for spatial navigation - we do
        # this centrally in the MainWidget
        if event.key() in [ Key.Key_Down, Key.Key_Up, Key.Key_Left, Key.Key_Right ]:
            # Note: if left-right navigation between buttons is needed, the
            # parent widget holding the buttons should handle it explicitly
            return self.parent().keyPressEvent(event)
        elif event.key() in [ Key.Key_Return, Key.Key_Enter ]:
            # Allow activating buttons with Enter/Return
            event.accept()
            self.click()
        else:
            super().keyPressEvent(event)

class LightButton(Button):
        def __init__(self, label, parent):
            super().__init__(label, (200, 200, 200), parent)

class DarkButton(Button):
        def __init__(self, label, parent):
            super().__init__(label, (0, 0, 0), parent)
