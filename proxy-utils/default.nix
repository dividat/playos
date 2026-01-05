{ pkgs ? (import ../pkgs {}) }:
with pkgs;
with lib;
python3Packages.buildPythonPackage rec {
    pname = "proxy_utils";
    version = "0.1.0";

    src = ./.;

    pyproject = true;
    build-system = with python3Packages; [ setuptools ];

    nativeBuildInputs = [
        wrapGAppsHook3
    ];

    nativeCheckInputs = with python3Packages; [
        ruff
        mypy
        pytest
    ];

    checkPhase = ''
        runHook preCheck

        ruff check

        mypy \
            --no-color-output \
            --pretty \
            --exclude 'build/.*' \
            --exclude 'test_.*' \
            --exclude setup.py \
            .

        pytest -v

        runHook postCheck
     '';


    propagatedBuildInputs = with python3Packages; [
        dbus-python
        pygobject3
    ];
}
