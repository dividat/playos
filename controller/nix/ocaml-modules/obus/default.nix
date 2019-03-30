{ stdenv, fetchFromGitHub, buildDunePackage
, camlp4, ocaml-migrate-parsetree, ppx_metaquot, ppx_tools_versioned, ocaml_lwt
, lwt_react, lwt_ppx, lwt_log, react, type_conv, xmlm }:

buildDunePackage rec {
  pname = "obus";
  version = "1.2.0-dev";

  minimumOCamlVersion = "4.03";

  src = fetchFromGitHub {
    owner = "dividat";
    repo = "obus";
    rev = "383ed2f7cbf22ae77fcf1d6399cbf7c667161114";
    sha256 = "1b5mg7npnsllg2kgdcqkpjd71w7abxzvzvyrnazqakzrw4sqw08y";
  };

  buildInputs = [ ];
  propagatedBuildInputs = 
    [ camlp4 ocaml-migrate-parsetree ppx_metaquot ppx_tools_versioned ocaml_lwt lwt_react lwt_ppx lwt_log react type_conv xmlm ];

  meta = {
    homepage = https://github.com/pukkamustard/obus;
    description = "Pure OCaml implementation of the D-Bus protocol";
    license = stdenv.lib.licenses.bsd3;
    maintainers = with stdenv.lib.maintainers; [ ];
  };
}
