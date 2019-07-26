from PyQt5.QtWidgets import QWidget, QPushButton, QHBoxLayout, QLabel

login_message = 'You must log in to this network before you can access the Internet.'

class CaptivePortalMessage(QWidget):

    def __init__(self, press_button):
        super(CaptivePortalMessage, self).__init__()

        self._label = QLabel()

        self._button = QPushButton()
        self._button.setFixedWidth(180)
        self._button.clicked.connect(press_button)

        self._layout = QHBoxLayout()
        self._layout.addWidget(self._label)
        self._layout.addWidget(self._button)

        self.setFixedHeight(40)
        self.setLayout(self._layout)

    def setOpenMessage(self):
        self._button.setText('Open Network Login Page')
        self._label.setText(login_message)

    def setCloseMessage(self, is_connected):
        self._button.setText('Close Network Login Page')
        if is_connected:
            self._label.setText('')
        else:
            self._label.setText(login_message)
