{ stdenv, fetchFromGitHub, pkgs, buildGoModule }:

let

  version = "2.4.0";

in buildGoModule rec {

  pname = "dividat-driver";
  inherit version;

  src = fetchFromGitHub {
    owner = "dividat";
    repo = "driver";
    rev = version;
    sha256 = "sha256-JeyV01WAhuPw1BIG1EJ4ET5HjSc7VwoWTZ/6EvVEC5Q=";
  };

  vendorHash = "sha256-Jj6aI85hZXGeWhJ8wq9MgI9uTm11tJZUdVwI90Pio4s=";

  nativeBuildInputs = with pkgs; [ pkg-config pcsclite ];
  buildInputs = with pkgs; [ pcsclite ];

  ldflags = [
    "-X github.com/dividat/driver/src/dividat-driver/server.version=${version}"
  ];

}
