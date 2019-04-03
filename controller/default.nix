{ fetchFromGitHub ? (import <nixpkgs> {}).fetchFromGitHub
, version ? "0.0.0"
, updateUrl ? "http://localhost:9999/"
, kioskUrl ? "https://dev-play.dividat.com/"}:

# We require two things for the OCaml build environment that are not yet in 18.09 channel (used by rest of project): https://github.com/NixOS/nixpkgs/pull/49684 and https://github.com/NixOS/nixpkgs/pull/53357.
with import (fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "43d4f07bf1144d6eb20975c956c7cc7bc643ea6e";
    sha256 = "0gm3majn0gvkdq2zvqrwyn1bi2zd8g0w34rngpfhdcf767l3l2l3";
    }) {overlays = [ (import ./nix/overlay.nix) ];};


ocamlPackages.buildDunePackage rec {
  pname = "playos_controller";
  inherit version;

  minimumOcamlVersion = "4.06";

  src = ./.;

  preConfigure = ''
    sed -i \
      -e "s,@PLAYOS_VERSION@,${version},g" \
      -e "s,@PLAYOS_UPDATE_URL@,${updateUrl},g" \
      -e "s,@PLAYOS_KIOSK_URL@,${kioskUrl},g" \
      ./server/info.ml
  '';

  buildInputs = with ocamlPackages; [ utop nodejs ];
  propagatedBuildInputs = with ocamlPackages; [
    # server side
    opium
    ocaml_lwt
    logs
    fpath
    tyxml
    cohttp-lwt-unix
    obus
    semver
    sexplib
    ezjsonm
    mustache
    containers

    # client side
    js_of_ocaml
    js_of_ocaml-tyxml
    cohttp-lwt-jsoo
  ];
}
