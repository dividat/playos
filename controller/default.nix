{ pkgs, version, updateUrl, kioskUrl }:

with pkgs;

ocamlPackages.buildDunePackage rec {
  pname = "playos_controller";
  inherit version;

  minimumOcamlVersion = "4.06";

  src = ./.;

  preConfigure = ''
    markdown Changelog.md > Changelog.html

    sed -i \
      -e "s,@PLAYOS_VERSION@,${version},g" \
      -e "s,@PLAYOS_UPDATE_URL@,${updateUrl},g" \
      -e "s,@PLAYOS_KIOSK_URL@,${kioskUrl},g" \
      ./server/info.ml
  '';

  useDune2 = true;

  buildInputs = with ocamlPackages; [
    discount # Transform Markdown to HTML
    nodejs
    utop
  ];

  propagatedBuildInputs = with ocamlPackages; [
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
    containers
    fieldslib
  ];
}
