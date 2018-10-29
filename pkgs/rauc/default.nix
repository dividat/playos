{stdenv, fetchurl, glib, curl, json-glib, pkgconfig, makeWrapper, grub2}:
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

    # Add grub2 to PATH so that rauc can use grub-editenv
    wrapProgram $out/bin/rauc \
      --prefix PATH ":" ${grub2}/bin
  '';
}
