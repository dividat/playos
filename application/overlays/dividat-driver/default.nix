{ stdenv, fetchFromGitHub, pkgs, buildGoModule }:

let

  version = "3.0.0-12bit";

in buildGoModule rec {

  pname = "dividat-driver";
  inherit version;

  src = fetchFromGitHub {
    owner = "dividat";
    repo = "driver";
    rev = "4344c15750dde9c91b92169cd0783866527f81d0";
    sha256 = "sha256-pRjNLElBUp0289BNd+DXYCyqLq92z9YlS4fPPBDyBH0=";
  };

  vendorHash = "sha256-Jj6aI85hZXGeWhJ8wq9MgI9uTm11tJZUdVwI90Pio4s=";

  nativeBuildInputs = with pkgs; [ pkg-config pcsclite ];
  buildInputs = with pkgs; [ pcsclite ];

  ldflags = [
    "-X github.com/dividat/driver/src/dividat-driver/server.version=${version}"
  ];

}
