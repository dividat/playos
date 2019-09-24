{ stdenv, fetchzip, ... }:

stdenv.mkDerivation rec {
  name = "breeze-contrast-cursor-theme";
  version = "1.0";

  src = fetchzip {
    url = "https://code.jpope.org/jpope/breeze_cursor_sources/raw/master/${name}.zip";
    sha256 = "1l8ils82bq2hlsl8shkcirxfjgk0459hsf6zvjnk9zrav47y9vjk";
    extraPostFetch = "chmod go-w $out";
  };

  installPhase = ''
    install -d $out/share/icons/Breeze_Contrast
    cp -rf * $out/share/icons/Breeze_Contrast
    find $out -type d -exec chmod 555 {} \;
  '';

  meta = {
    description = "Breeze Contrast cursor theme";
    homepage = https://kver.wordpress.com/2015/01/09/curses-i-mean-cursors/;
    license = stdenv.lib.licenses.gpl3;
    platforms = stdenv.lib.platforms.all;
  };
}
