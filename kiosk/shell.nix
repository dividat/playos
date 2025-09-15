let
  pkgs = import ../pkgs {};
  kiosk = import ./default.nix {
    pkgs = pkgs;
    system_name = "PlayOS";
    system_version = "1.0.0-dev";
    # enable test deps
    doCheck = true;
  };
in
  pkgs.mkShell {
    inputsFrom = [ kiosk ];

    shellHook = ''
      # Give access to kiosk_browser module
      export PYTHONPATH=./:$PYTHONPATH

      export FOCUS_SHIFT_PATH="${pkgs.focus-shift.main}"

      # Setup Qt environment.. in a hacky way
      tmpdir=$(mktemp -d)
      makeWrapper /bin/true "$tmpdir/setupQtEnv" "''${qtWrapperArgs[@]}"
      # remove the final exec
      sed -i '\|exec "/bin/true"|d' "$tmpdir/setupQtEnv"
      source "$tmpdir/setupQtEnv"
    '';
  }
