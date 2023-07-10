let
  pkgs = import ../pkgs {};
  playos-controller = import ./default.nix {
    pkgs = pkgs;
    version = "1.0.0-dev";
    bundleName = "playos";
    updateUrl = "http://localhost:9999/";
    kioskUrl = "https://dev-play.dividat.com/";
  };
in
  playos-controller.overrideAttrs(oldAttrs: {
    buildInputs = oldAttrs.buildInputs ++ (with pkgs; [
      python37Packages.pywatchman
    ]);
  })
