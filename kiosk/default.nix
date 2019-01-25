# TODO: Not so nice that entire pkgs is used as argument. We need to find a nice way where we can explicitly define arguments but also make it easy to cd into this directory and start a "local" nix shell or just build the local component.
{ pkgs ? (import <nixpkgs> {})}:
with pkgs;

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
