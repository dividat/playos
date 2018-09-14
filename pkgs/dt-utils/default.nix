{stdenv, fetchgit, autoreconfHook, libudev, pkgconfig}:
stdenv.mkDerivation rec {
  name = "dt-utils-${version}";
  version = "v2018.05.0";

  src = fetchgit {
    url = "https://git.pengutronix.de/git/tools/dt-utils";
    rev = version;
    sha256 = "0x7v5dlq5nm33sm9p6kgg9swdm94104s22z850kk92riqdmidcci";
  };

  nativeBuildInputs = [
    autoreconfHook
  ];

  buildInputs = [
    libudev
    pkgconfig
  ];
}
