{buildDunePackage, fetchFromGitHub, angstrom, ppxlib, ppx_inline_test, ocaml, lib}:
buildDunePackage rec {
  pname= "semver2";
  version = "1.2.0";

  minimumOCamlVersion = "4.04";

  src = fetchFromGitHub {
    owner = "dividat";
    repo = "ocaml-semver";
    rev = "8cc7449e5aa564a9b81152985078e6194861405b";
    sha256 = "0i5xp84wvzknij4kb7dsvhyvwl77l0wnajbxl8wi4ajsalwc87aw";
  };

  useDune2 = true;

  buildInputs = [];
  propagatedBuildInputs = [ angstrom ppxlib ppx_inline_test ];

  meta = {
    description = "Semantic version handling for OCaml.";
    license = lib.licenses.mit;
    homepage = "https://github.com/dividat/ocaml-semver";
    maintainers = [];
    inherit (ocaml.meta) platforms;
  };

}
