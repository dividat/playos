{ stdenv, fetchFromGitHub, pkgs, buildGoModule }:

let

  channel = "develop";

  version = "2.2.0-rc2";

  releaseUrl = "https://dist.dividat.com/releases/driver2/";

in buildGoModule rec {

  pname = "dividat-driver";
  inherit version;

  src = fetchFromGitHub {
    owner = "dividat";
    repo = "driver";
    rev = "9146cbf2f540cd5aa9cea5828f83993c8629657b";
    sha256 = "1lsh0lyjwdhk24zrryaqszl1k3356yzckzx32q7mbcvvkh17hs9q";
  };

  vendorSha256 = "1lvgp9q3g3mpmj6khbg6f1z9zgdlmwgf65rqx4d7v50a1m7g9a0m";

  nativeBuildInputs = with pkgs; [ pkgconfig pcsclite ];
  buildInputs = with pkgs; [ pcsclite ];

  ldflags = [
    "-X github.com/dividat/driver/src/dividat-driver/server.channel=${channel}"
    "-X github.com/dividat/driver/src/dividat-driver/server.version=${version}"
    "-X github.com/dividat/driver/src/dividat-driver/update.releaseUrl=${releaseUrl}"
  ];

}
