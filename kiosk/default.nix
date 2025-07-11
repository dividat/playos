{ pkgs, system_name, system_version, additional_inputs ? [] }:

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

  buildInputs = [
    bashInteractive
    makeWrapper
  ];

  nativeBuildInputs = [
    mypy
    qt6.wrapQtAppsHook
    wrapGAppsHook
  ];

  propagatedBuildInputs = with python3Packages; [
    dbus-python
    pygobject3
    pyqt6-webengine
    pytest
    qt6.qtbase
    requests
    types-requests
    playos-proxy-utils
  ] ++ additional_inputs;

  postInstall = ''
    cp -r images/ $out/images
  '';

  shellHook = ''
    # Give access to kiosk_browser module
    export PYTHONPATH=./:$PYTHONPATH

    # Setup Qt environment
    bashdir=$(mktemp -d)
    makeWrapper "$(type -p bash)" "$bashdir/bash" "''${qtWrapperArgs[@]}"
    exec "$bashdir/bash"
  '';
}
