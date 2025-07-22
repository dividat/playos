{ pkgs, qt6 }:
qt6.qtvirtualkeyboard.overrideAttrs (previous: {
    patches = [
        ./0001-handle-mismatch-between-latest-received-focusObject.patch
    ];

    # Note: according to Qt you should use `qt-configure-module`
    # from qtbase (https://wiki.qt.io/Qt_Build_System_Glossary#Per-repository_Build)
    # for configuration, but the `configure` script crashes due to
    # unknwon type `enableLang` specified in `vkb-enable` (if used) and
    # install fails due to incompatibilities with the nix setup.
    #
    # So instead we set the cmake flag directly and keep the bloated
    # version of qtvirtualkeyboard (handwriting support, spell
    # checker, all languages included, etc).
    cmakeFlags = [
        "-DFEATURE_vkb_arrow_keynavigation=ON"
    ] ++ (pkgs.lib.lists.optionals (previous ? cmakeFlags) previous.cmakeFlags);
})
