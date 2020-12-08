{buildDunePackage, fetchFromGitHub, angstrom, ppxlib, ppx_inline_test, ocaml, stdenv}:
buildDunePackage rec {
  pname= "semver2";
  version = "1.1.0";

  minimumOCamlVersion = "4.04";

  src = fetchFromGitHub {
    owner = "dividat";
    repo = "ocaml-semver";
    rev = "8dc25e0c6c8a149e95835c9e6dbf46c465459415";
    sha256 = "04ay8acddhillj2j208wlxhy9dnv47smnk1pzz3a9vbpxkbhdr6p";
  };

  buildInputs = [];
  propagatedBuildInputs = [ angstrom ppxlib ppx_inline_test ];

  meta = {
    description = "Semantic version handling for OCaml.";
    license = stdenv.lib.licenses.mit;
    homepage = "https://github.com/dividat/ocaml-semver";
    maintainers = [];
    inherit (ocaml.meta) platforms;
  };

}
