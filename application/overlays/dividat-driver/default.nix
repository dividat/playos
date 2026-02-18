{ stdenv, fetchFromGitHub, pkgs, buildGoModule }:

let

  version = "2.8.0";

in buildGoModule rec {

  pname = "dividat-driver";
  inherit version;

  src = fetchFromGitHub {
    owner = "dividat";
    repo = "driver";
    rev = version;
    sha256 = "sha256-gn7wzLxYWMrENyteEKmUD3mbVoOY9Dfi1I8Q2U8cQVQ=";
  };

  vendorHash = "sha256-GwV+DmGCYe/PvnimpVbUWziD4SCoZDm0U9aVfmrLqsI=";

  nativeBuildInputs = with pkgs; [ pkg-config pcsclite ];
  buildInputs = with pkgs; [ pcsclite ];

  ldflags = [
    "-X github.com/dividat/driver/src/dividat-driver/server.version=${version}"
  ];

}
