with import <nixpkgs> {};
#{ stdenv, lib, fetchurl, fetchzip, python3Packages
#, makeWrapper, qtbase, glib-networking, libxml2
#}:

let qtx=qt5; in
python3Packages.buildPythonApplication rec {
  pname = "playos_kiosk_browser";
  version = "0.1.0";

  src = builtins.filterSource
    (path: type: type != "directory" ||  baseNameOf path != "venv")
    ./.;

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
  ];

  makeWrapperArgs = [
      "--set QT_QPA_PLATFORM_PLUGIN_PATH ${qtbase.bin}/lib/qt-*/plugins/platforms"
  ];
}
