let
  pkgs = import ../pkgs {};
in
  import ./default.nix {
    pkgs = pkgs;
    system_name = "PlayOS";
    system_version = "1.0.0-dev";
  }

