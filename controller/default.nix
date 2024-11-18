{ pkgs, version, bundleName, updateUrl, kioskUrl }:

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

    sed -i \
      -e "s,@PLAYOS_BUNDLE_NAME@,${bundleName},g" \
      ./server/update.ml
  '';

  useDune2 = true;

  nativeBuildInputs = [
    discount # Transform Markdown to HTML
    ocamlPackages.obus
  ];

  buildInputs = with ocamlPackages; [
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
    ppx_protocol_conv
    ppx_protocol_conv_jsonm
  ];
}
