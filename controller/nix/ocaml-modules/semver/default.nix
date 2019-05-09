{buildDunePackage, fetchFromGitHub, angstrom, ppxlib, ppx_inline_test, ocaml, stdenv}:
buildDunePackage rec {
  pname= "semver";
  version = "0.1.0";

  minimumOCamlVersion = "4.04";

  src = fetchFromGitHub {
    owner = "dividat";
    repo = "ocaml-semver";
    rev = "ea51d2f6a60a6203978f9b10ffb3acf7a4178ef1";
    sha256 = "0i3k1m7cr8gzajwvi7yaikdfzwl122wgqy2wic9404dwffppxaqz";
  };

  buildInputs = [ ];
  propagatedBuildInputs = [ angstrom ppxlib ppx_inline_test ];

  meta = {
    description = " Semantic version handling for OCaml.";
    license = stdenv.lib.licenses.mit;
    homepage = "https://github.com/dividat/ocaml-semver";
    maintainers = [ ];
    inherit (ocaml.meta) platforms;
  };

}
