import QtQuick
import QtQuick.Window
import QtQuick.VirtualKeyboard
import QtQuick.VirtualKeyboard.Settings
import QtQuick.VirtualKeyboard.Styles

// Note: the InputPanel is initialized in a QQuickWidget with
// ResizeMode.SizeRootObjectToView, therefore it gets automatically resized
// and width/height/position is not updated here unlike in "normal" QML
// integrations that respond to `inputPanel.active`.
InputPanel {
    id: inputPanel
    x: 0
    y: 0
    z: 99
    property var plainInputMethod: PlainInputMethod {}

    Component.onCompleted: {
        // Note: activeLocales is provided via setContextProperty by parent
        VirtualKeyboardSettings.activeLocales = activeLocales.split(";");
        // Note: slightly questionable choice, because in addition to closing
        // the input form, it will also submit the form (if all required fields
        // are populated).
        VirtualKeyboardSettings.closeOnReturn = true;
        VirtualKeyboardSettings.handwritingModeDisabled = true;
        VirtualKeyboardSettings.defaultDictionaryDisabled = true;
        // we only use PlainInputMethod
        VirtualKeyboardSettings.defaultInputMethodDisabled = true;

        // we do not use selectionList and this is needed for keyboardBackgroundNumeric
        keyboard.style.selectionListBackground = null;
    }

    Component {
        id: keyboardBackgroundDefault;
        Rectangle {
            color: keyboard.style.keyboardBackgroundColor;
        }
    }

    Component {
        id: keyboardBackgroundNumeric
        Rectangle {
            color: keyboard.style.keyboardBackgroundColor;
            anchors.fill: parent
            anchors.leftMargin: (Window.width - keyboard.style.keyboardHeight) / 2
            anchors.rightMargin: (Window.width - keyboard.style.keyboardHeight) / 2
        }
    }

    Connections {
        target: Qt.inputMethod
        // Workaround to "input method is not set" error which happens when
        // keyboard is hidden while shifting between input fields of different types
        function onKeyboardRectangleChanged() {
            InputContext.inputEngine.inputMethod = null;
            InputContext.inputEngine.inputMethod = plainInputMethod;
        }
    }

    Connections {
        target: InputContext
        // Override the `ImhFormattedNumbersOnly` inputMethodHint to
        // `ImhDialableCharactersOnly` to show a more minimal keyboard without
        // extra formula inputs, which are useless in Play's context.
        //
        // Note 1: the input method hints are defined in `toQtInputMethodHints` of
        // qtwebengine: https://github.com/qt/qtwebengine/blob/6.9.1/src/core/type_conversion.cpp#L294
        //
        // Note 2: for some reason overriding with Qt.ImhDigitsOnly  has no effect.
        function onInputMethodHintsChanged() {
            const hints = InputContext.inputMethodHints;
            const digitsHintsToOverride = Qt.ImhFormattedNumbersOnly | Qt.ImhDigitsOnly;
            if (hints & digitsHintsToOverride) {
                // unset the overridable hints and set ImhDialableCharactersOnly
                let updatedHints = hints & ~digitsHintsToOverride | Qt.ImhDialableCharactersOnly;
                VirtualKeyboardSettings.inputMethodHints = updatedHints;
            }
            else {
                // this is a persistent property, so it needs to be explicitly reset
                VirtualKeyboardSettings.inputMethodHints = Qt.ImhNone;
            }

            // reduce the numeric keyboard left-right margins by making its background transparent
            if (hints & Qt.ImhDialableCharactersOnly) {
                keyboard.style.keyboardBackground = keyboardBackgroundNumeric;
            }
            else {
                keyboard.style.keyboardBackground = keyboardBackgroundDefault;
            }
        }
    }
}
