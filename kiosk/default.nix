{ pkgs, system_name, system_version, doCheck ? false }:

with pkgs;

python3Packages.buildPythonApplication rec {

  pname = "playos_kiosk_browser";
  version = "0.1.0";

  src = ./.;

  postPatch = ''
    substituteInPlace kiosk_browser/system.py \
      --replace "@system_name@" "${system_name}" \
      --replace "@system_version@" "${system_version}"

    substituteInPlace kiosk_browser/assets.py \
      --replace "@focus_shift_path@" "${pkgs.focus-shift.main}" \
  '';

  buildInputs = [
    bashInteractive
    makeWrapper
  ];

  nativeCheckInputs = with python3Packages; [
    mypy
    pytest
    pytest-qt
    pytest-xvfb # needed for qt tests
    types-requests
  ] ++ [ xorg.xvfb ];

  nativeBuildInputs = [
    qt6.wrapQtAppsHook
    wrapGAppsHook
  ];

  checkPhase = ''
    runHook preCheck

    ./bin/test

    runHook postCheck
  '';

  inherit doCheck;

  propagatedBuildInputs =
      [
        qt6.qtbase
        qt6.qtvirtualkeyboard
      ]
      ++ (with python3Packages; [
        dbus-python
        evdev
        pyudev
        pygobject3
        pyqt6-webengine
        requests
        playos-proxy-utils
      ]);

  postInstall = ''
    cp -r images/ $out/images
  '';

}
