let
  pkgs = import ../pkgs {};
in
  import ./default.nix {
    pkgs = pkgs;
    system_name = "PlayOS";
    system_version = "1.0.0-dev";
    # Provides qtwayland only for testing
    additional_inputs = [ pkgs.qt6.qtwayland ];
  }
