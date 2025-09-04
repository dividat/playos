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
pkgs.mkShell {
  packages =
    playos-controller.buildInputs
      ++ playos-controller.nativeBuildInputs
      ++ [
        pkgs.watchexec
        pkgs.ocamlformat
      ];

  shellHook = playos-controller.genAssetsHook;
}
