{ stdenv, fetchurl, ocaml, buildDunePackage
, ounit
, menhir, ezjsonm
}:

buildDunePackage rec {
  pname = "mustache";
  version = "3.0.2";

  minimumOcamlVersion = "4.02.3";

  src = fetchurl {
    url = "https://github.com/rgrinberg/ocaml-mustache/archive/v${version}.tar.gz";
    sha256 = "0libw5wy46w19m6dzxkj7mcwhwf3m225p15h996mxcmin8n7xvah";
  };

  buildInputs = [ ounit ];
  propagatedBuildInputs = [ menhir ezjsonm ];

  # TODO: Checks fail. Investigate why.
  doCheck = false;

  meta = {
    description = "Read and write mustache templates, and render them by providing a json object";
    license = stdenv.lib.licenses.mit;
    homepage = "https://github.com/rgrinberg/opium";
    maintainers = [ ];
    inherit (ocaml.meta) platforms;
  };
}
