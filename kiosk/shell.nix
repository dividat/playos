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

    shellHook = with pkgs.lib; ''
      # Give access to kiosk_browser module
      export PYTHONPATH=./:$PYTHONPATH

      export FOCUS_SHIFT_PATH="${pkgs.focus-shift.main}"

      ${optionalString (! pkgs.stdenv.isLinux) "export KIOSK_USE_MOCKS=1"}

      # Setup Qt environment.. in a hacky way
      tmpdir=$(mktemp -d)

      # the bin being wrapped is irrelevant, it just needs to exist and be executable
      makeWrapper bin/kiosk-browser "$tmpdir/setupQtEnv" "''${qtWrapperArgs[@]}"
      # remove the final exec
      sed -i '\|^exec |d' "$tmpdir/setupQtEnv"
      source "$tmpdir/setupQtEnv"
    '';
  }
