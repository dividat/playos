{ stdenv, fetchFromGitHub, pkgs, buildGoModule }:

let

  version = "2.2.0-rc2";

in buildGoModule rec {

  pname = "dividat-driver";
  inherit version;

  src = fetchFromGitHub {
    owner = "knuton";
    repo = "driver";
    rev = "839f4e42bfe7f5126a0944eff0b1f303ec2483eb";
    sha256 = "sha256-uUN/Rvo2qopmAVUUOm7W2Q9975bVUz1mvZWH0kcw9hQ=";
  };

  vendorSha256 = "sha256-oL7upl231aWbkBfybmP5fSTySFJkEI3vGKaWJu+Q30Q=";

  nativeBuildInputs = with pkgs; [ pkgconfig pcsclite ];
  buildInputs = with pkgs; [ pcsclite ];

  ldflags = [
    "-X github.com/dividat/driver/src/dividat-driver/server.version=${version}"
  ];

}
