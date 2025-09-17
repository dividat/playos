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

    Component.onCompleted: {
        // Note: activeLocales is provided via setContextProperty by parent
        VirtualKeyboardSettings.activeLocales = activeLocales.split(";");
        // we only use PlainInputMethod
        VirtualKeyboardSettings.handwritingModeDisabled = true;
        VirtualKeyboardSettings.defaultDictionaryDisabled = true;
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

    // recursively look for a child element with a specific property value
    function findChild(parent, propertyName, propertyValue) {
        if (parent[propertyName] == propertyValue) {
            return parent;
        }

        for (const child of parent.children) {
            const result = findChild(child, propertyName, propertyValue);
            if (result) {
                return result;
            }
        }

        return null;
    }

    // extra signal for detecting user-initiated keyboard hiding
    signal hideKeyboardClicked()

    // Attach an additional click handler to the HideKeyboardKey in a slightly hacky way
    onActiveChanged: {
        if (inputPanel.active) {
            // Qt.callLater needed because on "first display" the layout does
            // not seem to be fully initialized and HideKeyboardKey is not found
            Qt.callLater(function() {
                // The hack: there is no id/ref that we can use, so we search by property
                let child = findChild(inputPanel.keyboard, "keyType", QtVirtualKeyboard.KeyType.HideKeyboardKey);
                if (child) {
                    try { child.clicked.disconnect(inputPanel.hideKeyboardClicked) } catch (e) {};
                    child.clicked.connect(inputPanel.hideKeyboardClicked);
                }
            });
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
