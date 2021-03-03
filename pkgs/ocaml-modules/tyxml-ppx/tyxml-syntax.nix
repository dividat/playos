{ lib, buildDunePackage, fetchurl, re, uutf, ppx_tools_versioned }:

buildDunePackage rec {
  pname = "tyxml-syntax";
  version = "4.4.0";

  src = fetchurl {
    url = "https://github.com/ocsigen/tyxml/releases/download/${version}/tyxml-${version}.tbz";
    sha256 = "0c150h2f4c4id73ickkdqkir3jya66m6c7f5jxlp4caw9bfr8qsi";
  };

  propagatedBuildInputs = [
    uutf
    re
    ppx_tools_versioned
  ];

  meta = with lib; {
    homepage = "http://ocsigen.org/tyxml/";
    description = "Common layer for the JSX and PPX syntaxes for Tyxml";
    license = licenses.lgpl21;
    maintainers = [];
  };
}
