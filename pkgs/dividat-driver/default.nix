{stdenv, fetchurl}:
stdenv.mkDerivation rec {
  name = "dividat-driver-${version}";
  version = "2.1.0";
  channel = "master";

  src = fetchurl {
    url = "https://dist.dividat.com/releases/driver2/${channel}/${version}/dividat-driver-linux-amd64-${version}";
    sha256 = "0f5hd7mxrhsaxmwdyys1vk9z5rxm57y3w7qjlqj7l5v2v41g0vrm";
  };

  buildCommand = ''
    mkdir -p $out/bin
    cp $src $out/bin/dividat-driver
    chmod +x $out/bin/dividat-driver
  '';

}
