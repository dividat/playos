{ buildDunePackage
, fetchFromGitHub
, lib
, base
, ppxlib
, ppx_fields_conv
, ppx_sexp_conv
, sexplib
, alcotest
}:

buildDunePackage rec {
  pname = "ppx_protocol_conv";
  version = "5.2.3";

  minimumOCamlVersion = "4.08";

  src = fetchFromGitHub {
    owner = "andersfugmann";
    repo = "ppx_protocol_conv";
    rev = "425a7a1a26c26fcb740e5574e252043fd03eff46";
    sha256 = "sha256-G6zMgHioPUCh2i50cjQ6talN8CYO6UhEaWgi0xe3CWA=";
  };

  useDune2 = true;

  propagatedBuildInputs = [
    base
    ppxlib
    ppx_fields_conv
    ppx_sexp_conv
    sexplib
    alcotest
  ];

  meta = {
    homepage = https://github.com/andersfugmann/ppx_protocol_conv;
    description = "Ppx for generating serialisation and de-serialisation functions of ocaml types";
    license = lib.licenses.bsd3;
    maintainers = [ ];
  };
}
