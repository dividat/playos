{ stdenv, fetchFromGitHub, pkgs, buildGoModule }:

let

  version = "2.3.0";

in buildGoModule rec {

  pname = "dividat-driver";
  inherit version;

  src = fetchFromGitHub {
    owner = "dividat";
    repo = "driver";
    rev = version;
    sha256 = "sha256-OLSd+q5oe5Fd7GtKsJkkpTiEndpt/x1X0xdzGzZ7Zpg=";
  };

  vendorHash = "sha256-oL7upl231aWbkBfybmP5fSTySFJkEI3vGKaWJu+Q30Q=";

  nativeBuildInputs = with pkgs; [ pkg-config pcsclite ];
  buildInputs = with pkgs; [ pcsclite ];

  ldflags = [
    "-X github.com/dividat/driver/src/dividat-driver/server.version=${version}"
  ];

}
