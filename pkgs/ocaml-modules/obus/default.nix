{ lib, fetchFromGitHub, buildDunePackage
, ppxlib, ppx_tools_versioned, ocaml_lwt
, lwt_react, lwt_ppx, lwt_log, react, xmlm, menhir }:

buildDunePackage rec {
  pname = "obus";
  version = "1.2.4";

  minimumOCamlVersion = "4.04";

  src = fetchFromGitHub {
    owner = "ocaml-community";
    repo = "obus";
    rev = "0c5ec967da943d75d11b6c65460c306e37993b23";
    sha256 = "1g8mn5851vzzq7cbv4i51aq4xls1d4krzw2zxs96vf26mdnwvfxi";
  };

  useDune2 = true;

  buildInputs = [ ];
  propagatedBuildInputs = [
    lwt_log
    lwt_ppx
    lwt_react
    menhir
    ocaml_lwt
    ppxlib
    react
    xmlm
  ];

  meta = {
    homepage = https://github.com/ocaml-community/obus;
    description = "Pure OCaml implementation of the D-Bus protocol";
    license = lib.licenses.bsd3;
    maintainers = with lib.maintainers; [ ];
  };
}
