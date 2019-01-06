{ stdenv, fetchurl, ocaml, buildDunePackage, findlib
, alcotest, cow
, opium_kernel, cohttp-lwt-unix, ocaml_lwt, cmdliner, ppx_fields_conv, ppx_sexp_conv, re, magic-mime}:

buildDunePackage rec {
  pname = "opium";
  version = "0.17.0";

  minimumOcamlVersion = "4.04.1";

  src = fetchurl {
    url = "https://github.com/rgrinberg/opium/releases/download/v0.17.0/opium-v0.17.0.tbz";
    sha256 = "17vqwjm1ziwa1l6nkvbbfk8b9wxdlsdx11w4zwvm77wm5licsxmj";
  };

  buildInputs = [ alcotest cow ];
  propagatedBuildInputs = [ opium_kernel cohttp-lwt-unix ocaml_lwt cmdliner ppx_fields_conv ppx_sexp_conv re magic-mime
  ];
  doCheck = true;

  meta = {
    description = "Sinatra like web toolkit based on Lwt + Cohttp";
    license = stdenv.lib.licenses.mit;
    homepage = "https://github.com/rgrinberg/opium";
    maintainers = [ ];
    inherit (ocaml.meta) platforms;
  };
}
