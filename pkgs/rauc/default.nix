{stdenv, fetchurl, autoreconfHook, dbus, glib, curl, json-glib, pkgconfig, makeWrapper, grub2, utillinux, squashfsTools, e2fsprogs, gnutar, xz, ...}:
stdenv.mkDerivation rec {
  name = "rauc-${version}";
  version = "1.2";

  buildInputs = [ autoreconfHook glib curl json-glib pkgconfig makeWrapper dbus ];

  src = fetchurl {
    url = "https://github.com/rauc/rauc/releases/download/v${version}/rauc-${version}.tar.xz";
    sha256 = "sha256:0qg6frrih1q81r0x9byy4nxjd3nd8mj7iai8j6wcql5c3zy86ii2";
  };

  configureFlags = [
    "--with-dbuspolicydir=${placeholder "out"}/etc/dbus-1/system.d"
    "--with-dbussystemservicedir=${placeholder "out"}/etc/dbus-1/system-services"
    "--with-dbusinterfacesdir=${placeholder "out"}/etc/dbus-1/system.d"
  ];

  postInstall = ''
    # Add required tools to path
    wrapProgram $out/bin/rauc \
      --prefix PATH ":" ${utillinux}/bin \
      --prefix PATH ":" ${squashfsTools}/bin \
      --prefix PATH ":" ${e2fsprogs}/bin \
      --prefix PATH ":" ${grub2}/bin \
      --prefix PATH ":" ${gnutar}/bin \
      --prefix PATH ":" ${xz}/bin
  '';
}
