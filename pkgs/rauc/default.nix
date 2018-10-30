{stdenv, fetchurl, glib, curl, json-glib, pkgconfig, makeWrapper, grub2, utillinux, squashfsTools, e2fsprogs, gnutar, xz, ...}:
stdenv.mkDerivation rec {
  name = "rauc-${version}";
  version = "1.0.rc1";

  buildInputs = [ glib curl json-glib pkgconfig makeWrapper ];

  src = fetchurl {
    url = "https://github.com/rauc/rauc/releases/download/v1.0-rc1/rauc-${version}.tar.xz";
    sha256 = "0c4p1c1ghlcfzv8x7qncgmxgj9gdra4dmfwznyashihrr47m780d";
  };

  postInstall = ''
    # Move dbus configuration to right place so that it is picked up by NixOS machinery
    mkdir -p $out/etc/dbus-1
    mv $out/share/dbus-1/system.d $out/etc/dbus-1/

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
