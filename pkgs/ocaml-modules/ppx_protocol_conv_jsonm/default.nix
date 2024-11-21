{ buildDunePackage
, fetchFromGitHub
, lib
, ppx_protocol_conv
, ezjsonm
, ppx_sexp_conv
, sexplib
, alcotest
}:

buildDunePackage rec {
  pname = "ppx_protocol_conv_jsonm";
  version = "5.2.1";

  minimumOCamlVersion = "4.08";

  src = fetchFromGitHub {
    owner = "andersfugmann";
    repo = "ppx_protocol_conv";
    rev = "9a1c4f450cf4fc797e09296d736e5c21f6eb7c4a";
    sha256 = "sha256-3WlpuuRJfZA6UaeuJRuYI2Z9J7Yng+/J09BDmETwy30=";
  };

  useDune2 = true;

  patches = [
    ./remove-runtime-dependency-from-ppxlib.patch
  ];

  propagatedBuildInputs = [
    ppx_protocol_conv
    ezjsonm
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
