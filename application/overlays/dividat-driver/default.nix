{ stdenv, fetchFromGitHub, pkgs, buildGoModule }:

let

  version = "2.6.0";

in buildGoModule rec {

  pname = "dividat-driver";
  inherit version;

  src = fetchFromGitHub {
    owner = "dividat";
    repo = "driver";
    rev = version;
    sha256 = "sha256-ssRGJ0p2Bld5BuwyKD057NNjDS5ukk+x73DR73SrOz0=";
  };

  vendorHash = "sha256-Jj6aI85hZXGeWhJ8wq9MgI9uTm11tJZUdVwI90Pio4s=";

  nativeBuildInputs = with pkgs; [ pkg-config pcsclite ];
  buildInputs = with pkgs; [ pcsclite ];

  ldflags = [
    "-X github.com/dividat/driver/src/dividat-driver/server.version=${version}"
  ];

}
