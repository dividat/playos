{ stdenv, fetchurl, ocaml, buildDunePackage, findlib
, alcotest, cow
, hmap, cohttp, cohttp-lwt, ezjsonm, base64, ocaml_lwt, fieldslib, sexplib, ppx_fields_conv, ppx_sexp_conv, re}:

buildDunePackage rec {
  pname = "opium_kernel";
  version = "0.17.0";

  minimumOcamlVersion = "4.04.1";

  src = fetchurl {
    url = "https://github.com/rgrinberg/opium/releases/download/v0.17.0/opium-v0.17.0.tbz";
    sha256 = "17vqwjm1ziwa1l6nkvbbfk8b9wxdlsdx11w4zwvm77wm5licsxmj";
  };

  buildInputs = [ alcotest cow ];
  propagatedBuildInputs = [ hmap cohttp cohttp-lwt ezjsonm base64 ocaml_lwt fieldslib sexplib ppx_fields_conv ppx_sexp_conv re ];
  doCheck = true;

  meta = {
    description = "Opium_kernel is the Unix indpendent core of Opium. Useful for extremely portable environments such as mirage.";
    license = stdenv.lib.licenses.mit;
    homepage = "https://github.com/rgrinberg/opium";
    maintainers = [ ];
    inherit (ocaml.meta) platforms;
  };
}
