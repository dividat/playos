let
  pkgs = import ../../pkgs { };
  application = import ../../application.nix;
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    python3
    poetry
  ];

  shellHook = ''
    if [ ! -d "./venv" ]; then
      echo "Setting up virtualenv"
      python -m venv venv
    fi

    source ./venv/bin/activate

    cd ./macos
    echo "Installing dependencies with poetry"
    poetry install --no-root
    cd ..

    export PYTHONPATH="$PWD:$PWD/kiosk_browser:$PYTHONPATH"
    export PLAYOS_VERSION="${application.version}"
    echo "Ready"
  '';
}
