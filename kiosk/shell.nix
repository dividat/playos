let
  pkgs = import ../pkgs {
    version = "1.0.0-dev";
  };
in
  pkgs.playos-kiosk-browser
