{ pkgs ? (import ../pkgs {}) }:
with pkgs;
with lib;
python3Packages.buildPythonPackage rec {
    pname = "proxy_utils";
    version = "0.1.0";

    src = ./.;

    nativeBuildInputs = [
        wrapGAppsHook
    ];

    nativeCheckInputs = with python3Packages; [
        ruff
        mypy
    ];

     checkPhase = ''
        runHook preCheck

        ruff check

        mypy \
            --no-color-output \
            --pretty \
            --exclude 'build/.*' \
            --exclude setup.py \
            .

        runHook postCheck
     '';


    propagatedBuildInputs = with python3Packages; [
        dbus-python
        pygobject3
    ];
}
