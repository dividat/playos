from PyQt5.QtWidgets import QWidget, QPushButton, QHBoxLayout, QLabel, QSizePolicy

login_message = 'You must log in to this network before you can access the Internet.'

class CaptivePortalMessage(QWidget):

    def __init__(self, press_button):
        super(CaptivePortalMessage, self).__init__()

        self._label = QLabel()
        labelPolicy = QSizePolicy()
        labelPolicy.setHorizontalStretch(1)
        labelPolicy.setHorizontalPolicy(QSizePolicy.Preferred)
        self._label.setSizePolicy(labelPolicy)

        self._button = QPushButton()
        self._button.clicked.connect(press_button)

        self._layout = QHBoxLayout()
        self._layout.addWidget(self._label)
        self._layout.addWidget(self._button)

        self.setLayout(self._layout)

    def setOpenMessage(self):
        self._button.setText('Open Network Login Page')
        self._label.setText(login_message)

    def setCloseMessage(self, is_captive):
        self._button.setText('Close Network Login Page')
        if is_captive:
            self._label.setText(login_message)
        else:
            self._label.setText('')
