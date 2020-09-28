{ pkgs, ... }:

with pkgs;

stdenv.mkDerivation rec {
  pname = "pacrunner";
  version = "0.17";

  src = builtins.fetchGit {
    name = "pacrunner";
    url = "https://git.kernel.org/pub/scm/network/connman/${pname}.git";
    rev = "6f2ba9396ead9909c9f427651ee005834fbd05a8"; # tags/0.17
  };

  nativeBuildInputs = [
    autoreconfHook
    pkg-config
  ];

  buildInputs = [
    curl
    dbus
    glib
  ];

  preConfigurePhases = [ "bootstrapPhase" ];

  bootstrapPhase = ''
    ./bootstrap
  '';

  configureFlags = [
    "--sbindir=${placeholder "out"}/bin"
    "--with-dbusdatadir=${placeholder "out"}/share"
    "--with-dbusconfdir=${placeholder "out"}/share"
    "--enable-pie"
    "--enable-duktape"
    "--enable-curl"
    "--enable-libproxy"
  ];

  # installFlags = "DESTDIR=${placeholder "out"}";

  meta = with stdenv.lib; {
    description = "Proxy configuration daemon";
    platforms = platforms.linux;
    license = licenses.lgpl21;
  };
}
