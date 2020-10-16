{ stdenv, fetchzip, ... }:

# Inspiration:
# https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=breeze-contrast-cursor-theme
stdenv.mkDerivation rec {
  name = "breeze-contrast-cursor-theme";
  version = "1.0";
  themeName = "Breeze_Contrast";

  src = ./theme;

  installPhase = ''
    install -d $out/share/icons
    cp -r share/icons/${themeName} $out/share/icons/${themeName}
  '';

  meta = {
    description = "Breeze Contrast cursor theme";
    homepage = https://kver.wordpress.com/2015/01/09/curses-i-mean-cursors/;
    license = stdenv.lib.licenses.gpl3;
    platforms = stdenv.lib.platforms.all;
  };
}
