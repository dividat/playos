{ pkgs, qt6 }:
qt6.qtvirtualkeyboard.overrideAttrs (previous: {
    patches = [
        ./0001-handle-mismatch-between-latest-received-focusObject.patch
    ];

    # Note 1: according to Qt you should use `qt-configure-module`
    # from qtbase (https://wiki.qt.io/Qt_Build_System_Glossary#Per-repository_Build)
    # for configuration, but the `configure` script crashes due to
    # unknwon type `enableLang` specified in `vkb-enable` (if used) and
    # install fails due to incompatibilities with the nix setup.
    #
    # So instead we set the cmake flag directly and keep the bloated
    # version of qtvirtualkeyboard (handwriting support, spell
    # checker, all languages included, etc).
    #
    # Note 2: in future Qt releases, arrow key navigation will be configurable
    # at runtime with `VirtualKeyboardSettings.arrowKeyNavigationEnabled`,
    # see: https://codereview.qt-project.org/c/qt/qtvirtualkeyboard/+/652171
    cmakeFlags = [
        "-DFEATURE_vkb_arrow_keynavigation=ON"
    ] ++ (pkgs.lib.lists.optionals (previous ? cmakeFlags) previous.cmakeFlags);
})
