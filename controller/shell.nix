let
  pkgs = import ../pkgs {};
  playos-controller = import ./default.nix {
    pkgs = pkgs;
    version = "1.0.0-dev";
    bundleName = "playos";
    updateUrl = "http://localhost:9999/";
    kioskUrl = "https://dev-play.dividat.com/";
    doCheck = true;
  };
in
pkgs.mkShell {
  passthru.controller = playos-controller;

  inputsFrom = [ playos-controller ];

  packages =
      [
        pkgs.watchexec
      ];

  shellHook = playos-controller.genAssetsHook;
}
