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
    # Unreleased, we need https://github.com/ocaml-community/obus/pull/28
    rev = "03129dac072e7a7370c2c92b9d447e47f784b7c7";
    sha256 = "/IVbn9bgZgxfXbpfrj2PRv06rylL59BTVEzVDZ16fgc=";
  };

  useDune2 = true;

  nativeBuildInputs = [ menhir ];
  propagatedBuildInputs = [
    lwt_log
    lwt_ppx
    lwt_react
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
