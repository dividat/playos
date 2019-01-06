{ stdenv, fetchurl, ocaml, findlib, ocamlbuild, topkg, result }:

let
  pname = "hmap";
in

assert stdenv.lib.versionAtLeast ocaml.version "4.02.0";

stdenv.mkDerivation rec {
  name = "ocaml-${pname}-${version}";
  version = "0.8.1";

  src = fetchurl {
    url = "http://erratique.ch/software/${pname}/releases/${pname}-${version}.tbz";
    sha256 = "10xyjy4ab87z7jnghy0wnla9wrmazgyhdwhr4hdmxxdn28dxn03a";
  };

  nativeBuildInputs = [ ocamlbuild topkg ];
  buildInputs = [ ocaml findlib ];
  propagatedBuildInputs = [ result ];

  inherit (topkg) buildPhase installPhase;

  meta = with stdenv.lib; {
    homepage = http://erratique.ch/software/hmap;
    description = "Heterogeneous value maps for OCaml";
    license = licenses.isc;
    platforms = ocaml.meta.platforms or [];
    maintainers = [ ];
  };
}
