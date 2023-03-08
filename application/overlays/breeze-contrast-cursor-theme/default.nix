{ stdenv, unzip, lib, ... }:

# Inspiration:
# https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=breeze-contrast-cursor-theme
stdenv.mkDerivation rec {
  name = "breeze-contrast-cursor-theme";
  version = "1.0";
  themeName = "Breeze_Contrast";

  buildInputs = [ unzip ];

  # From mirror at https://code.jpope.org/jpope/breeze_cursor_sources
  # We inline the ZIP as the mirror was sometimes unreachable in the past.
  src = ./breeze-contrast-cursor-theme.zip;

  installPhase = ''
    install -d $out/share/icons/${themeName}
    cp -rf * $out/share/icons/${themeName}
  '';

  meta = {
    description = "Breeze Contrast cursor theme";
    homepage = https://kver.wordpress.com/2015/01/09/curses-i-mean-cursors/;
    license = lib.licenses.gpl2;
    platforms = lib.platforms.all;
  };
}
