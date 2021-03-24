{ stdenv, fetchFromGitHub, buildDunePackage
, ocaml-migrate-parsetree, ppxlib, ppx_tools_versioned, ocaml_lwt
, lwt_react, lwt_ppx, lwt_log, react, type_conv, xmlm, menhir }:

buildDunePackage rec {
  pname = "obus";
  version = "1.2.2";

  minimumOCamlVersion = "4.04";

  src = fetchFromGitHub {
    owner = "ocaml-community";
    repo = "obus";
    rev = "8aaf3d4e5538e42a62ae206dcfc01d2b898e54dc"; # 1.2.2
    sha256 = "145c9ir0a4ld054npq80q8974fangirmd4r7z0736qjva27raqr7";
  };

  buildInputs = [ ];
  propagatedBuildInputs = [
    lwt_log
    lwt_ppx
    lwt_react
    menhir
    ocaml-migrate-parsetree
    ocaml_lwt
    ppxlib
    react
    xmlm
  ];

  meta = {
    homepage = https://github.com/ocaml-community/obus;
    description = "Pure OCaml implementation of the D-Bus protocol";
    license = stdenv.lib.licenses.bsd3;
    maintainers = with stdenv.lib.maintainers; [ ];
  };
}
