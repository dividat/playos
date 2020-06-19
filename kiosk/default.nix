{ pkgs, system_name, system_version }:

with pkgs;

let qtx=qt5; in

python3Packages.buildPythonApplication rec {
  pname = "playos_kiosk_browser";
  version = "0.1.0";

  src = builtins.filterSource
    (path: type: type != "directory" ||  baseNameOf path != "venv")
    ./.;

  postPatch = ''
    substituteInPlace kiosk_browser/system.py \
      --replace "@system_name@" "${system_name}" \
      --replace "@system_version@" "${system_version}"
  '';

  doCheck = false;

  qtbase = qtx.qtbase;
  qtwebengine = qtx.qtwebengine;

  buildInputs = [
    qtbase
    qtwebengine
    glib-networking
    gst-plugins-base gst-plugins-good
    gst-plugins-bad gst-plugins-ugly gst_all_1.gst-libav
  ];

  nativeBuildInputs = [
    makeWrapper
  ];

  propagatedBuildInputs = with python3Packages; [
    pyqt5
    pyqtwebengine
    requests
  ];

  makeWrapperArgs = [
    "--set QT_QPA_PLATFORM_PLUGIN_PATH ${qtbase.bin}/lib/qt-*/plugins/platforms"
    "--set QT_PLUGIN_PATH ${qtbase.bin}/lib/qt-*/plugins"
  ];

  shellHook = ''
    export QT_QPA_PLATFORM_PLUGIN_PATH="$(echo ${qtx.qtbase.bin}/lib/qt-*/plugins/platforms)"
    export QT_PLUGIN_PATH="$(echo ${qtbase.bin}/lib/qt-*/plugins)"
    export PYTHONPATH=./:$PYTHONPATH # Give access to kiosk_browser module
  '';
}
