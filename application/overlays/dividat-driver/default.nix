{ stdenv, fetchFromGitHub, pkgs, buildGoModule }:

let

  version = "2.3.0-105-g36e3e91";

in buildGoModule rec {

  pname = "dividat-driver";
  inherit version;

  src = fetchFromGitHub {
    owner = "dividat";
    repo = "driver";
    rev = "36e3e91529c27e47fde9033f44154e22f2960b40";
    sha256 = "sha256-uYCPBllDYCynPvekP6siop5u6uXY/0Kd4enL2/0nmcU=";
  };

  vendorHash = "sha256-Jj6aI85hZXGeWhJ8wq9MgI9uTm11tJZUdVwI90Pio4s=";

  nativeBuildInputs = with pkgs; [ pkg-config pcsclite ];
  buildInputs = with pkgs; [ pcsclite ];

  ldflags = [
    "-X github.com/dividat/driver/src/dividat-driver/server.version=${version}"
  ];

}
