{ pkgs, version, bundleName, updateUrl, kioskUrl }:

with pkgs;

ocamlPackages.buildDunePackage rec {
  pname = "playos_controller";
  inherit version;

  minimumOcamlVersion = "4.06";

  src = ./.;

  preConfigure = let
    subs = {
        "@PLAYOS_VERSION@" = version;
        "@PLAYOS_UPDATE_URL@" = updateUrl;
        "@PLAYOS_KIOSK_URL@" = kioskUrl;
        "@PLAYOS_BUNDLE_NAME@" = bundleName;
    };
    in
    ''
    markdown Changelog.md > Changelog.html

    ${lib.strings.toShellVar "subs_arr" subs}

    for name in "''${!subs_arr[@]}"; do
        # check that the specified template variables are used
        grep -q $name ./config/config.ml || \
            (echo "$name is missing in ./config/config.ml"; exit 1)
        sed -i -e "s,$name,''${subs_arr[$name]},g" ./config/config.ml
    done
  '';

  postFixup = ''
    for prog in "$out"/bin/*; do
        wrapProgram $prog \
            --prefix PATH ":" ${lib.makeBinPath [ curl ]}
    done
  '';

  useDune2 = true;

  nativeBuildInputs = [
    pkgs.makeWrapper
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
    alcotest
    alcotest-lwt
    qcheck
    qcheck-alcotest
  ];
}
