{stdenv, fetchFromGitHub, buildGoPackage, pkgs}:

let
  sources = fetchFromGitHub {
    owner = "dividat";
    repo = "driver";
    rev = "6b1f9c925bdb4f91cb3b92393ed5425bb95cd351";
    sha256 = "11xpgkbpl5l1n3xg770zjyg48h5zkwrfhw98ii7iw2lxpiis3gm7";
  };
in
buildGoPackage rec {
  name = "dividat-driver-${version}";
  version = "2.1.0";

  src = "${sources}/src/dividat-driver";

  goPackagePath = "dividat-driver";
  goDeps = "${sources}/nix/deps.nix";

  nativeBuildInputs = with pkgs; [ pkgconfig pcsclite ];
  buildInputs = with pkgs; [ pcsclite ];
}
