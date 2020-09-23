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
    rev = "59c93162a4d4fc239761874f83d489332844e7c7"; # 1.2.0
    sha256 = "0qb42634dmx8g6rf6vv5js88d8vgbzz8646dsg638352yzgsi3a3";
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
    type_conv
    xmlm
  ];

  meta = {
    homepage = https://github.com/ocaml-community/obus;
    description = "Pure OCaml implementation of the D-Bus protocol";
    license = stdenv.lib.licenses.bsd3;
    maintainers = with stdenv.lib.maintainers; [ ];
  };
}
