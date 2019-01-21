{buildOcaml, fetchFromGitHub}:
buildOcaml rec {
  name= "semver";
  version = "0.1.0";

  minimumOCamlVersion = "4.02";

  src = fetchFromGitHub {
    owner = "rgrinberg";
    repo = "ocaml-semver";
    rev = "905c063a84935765f21fcc632c28a35dbc3b3e3d";
    sha256 = "0f8id2pxn2k6bfnnp5w2s9k37wsf457q6im7il815fg9ajwxw76h";
  };


}
