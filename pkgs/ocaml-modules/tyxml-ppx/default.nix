{ lib, buildDunePackage, fetchurl, tyxml, markup, re, uutf, ppx_tools_versioned }:

let

  tyxml-syntax = import ./tyxml-syntax.nix {
    inherit lib buildDunePackage fetchurl re uutf ppx_tools_versioned;
  };

in buildDunePackage rec {
  pname = "tyxml-ppx";
  version = "4.4.0";

  src = fetchurl {
    url = "https://github.com/ocsigen/tyxml/releases/download/${version}/tyxml-${version}.tbz";
    sha256 = "0c150h2f4c4id73ickkdqkir3jya66m6c7f5jxlp4caw9bfr8qsi";
  };

  propagatedBuildInputs = [
    tyxml
    tyxml-syntax
    markup
    ppx_tools_versioned
  ];

  meta = with lib; {
    homepage = "http://ocsigen.org/tyxml/";
    description = "PPX that allows to write TyXML documents with the HTML syntax";
    license = licenses.lgpl21;
    maintainers = with maintainers; [ gal_bolle vbgl ];
  };
}
