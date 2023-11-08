{ pkgs, system_name, system_version }:

with pkgs;

python3Packages.buildPythonApplication rec {

  pname = "playos_kiosk_browser";
  version = "0.1.0";

  src = ./.;

  postPatch = ''
    substituteInPlace kiosk_browser/system.py \
      --replace "@system_name@" "${system_name}" \
      --replace "@system_version@" "${system_version}"
  '';

  doCheck = false;

  nativeBuildInputs = [ qt5.wrapQtAppsHook ];

  propagatedBuildInputs = with python3Packages; [
    pyqtwebengine
    requests
    dbus-python
    pygobject3
    pytest
  ];

  postInstall = ''
    cp -r images/ $out/images
  '';

  dontWrapQtApps = true;
  makeWrapperArgs = [ "\${qtWrapperArgs[@]}" ];

  shellHook = ''
    # Give access to kiosk_browser module
    export PYTHONPATH=./:$PYTHONPATH

    # Give access to Qt platform plugin "xcb" in nix-shell
    export QT_QPA_PLATFORM_PLUGIN_PATH="${qt5.qtbase.bin}/lib/qt-${qt5.qtbase.version}/plugins";
  '';

}
