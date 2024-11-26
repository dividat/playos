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
    rev = "0a4fd698932f20345cb3ba12bab82a9eda4d9147";
    sha256 = "sha256-gFYg0251NOPPkc01BiSU3NEj3JWGKg1fu6UgQ67BBZM=";
  };

  useDune2 = true;

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
