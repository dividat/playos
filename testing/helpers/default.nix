{ pkgs ? (import ../../pkgs {}) }:
with pkgs;
with lib;
python3Packages.buildPythonPackage {
    pname = "playos_test_helpers";
    version = "0.1.0";

    src = ./.;

    pyproject = true;
    build-system = with python3Packages; [ setuptools ];

    nativeCheckInputs = with python3Packages; [
        mypy
        types-colorama
    ];

    checkPhase = ''
        runHook preCheck

        mypy \
            --no-color-output \
            --pretty \
            --exclude 'build/.*' \
            --exclude setup.py \
            .

        runHook postCheck
     '';

    propagatedBuildInputs = with python3Packages; [
        colorama
    ];
}
