{ pkgs, version, updateUrl, kioskUrl }:

with pkgs;

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
