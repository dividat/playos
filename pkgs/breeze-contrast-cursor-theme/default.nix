{ stdenv, fetchzip, ... }:

# Inspiration:
# https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=breeze-contrast-cursor-theme
stdenv.mkDerivation rec {
  name = "breeze-contrast-cursor-theme";
  version = "1.0";
  themeName = "Breeze_Contrast";

  src = fetchzip {
    url = "https://code.jpope.org/jpope/breeze_cursor_sources/raw/master/${name}.zip";
    sha256 = "1l8ils82bq2hlsl8shkcirxfjgk0459hsf6zvjnk9zrav47y9vjk";
  };

  installPhase = ''
    install -d $out/share/icons/${themeName}
    cp -rf * $out/share/icons/${themeName}
  '';

  meta = {
    description = "Breeze Contrast cursor theme";
    homepage = https://kver.wordpress.com/2015/01/09/curses-i-mean-cursors/;
    license = stdenv.lib.licenses.gpl3;
    platforms = stdenv.lib.platforms.all;
  };
}
