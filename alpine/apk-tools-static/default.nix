{ stdenv, fetchurl }:
    stdenv.mkDerivation rec {
      name = "apk-tools-${version}";
      version = "2.9.1";
      release = "2";
      src = fetchurl {
        url = "http://dl-cdn.alpinelinux.org/alpine/v3.7/main/x86_64/apk-tools-static-${version}-r${release}.apk";
        name = "apk-tools.tar.gz";
        sha256 = "1y9qzp7qk2f583m3s5ysrdjjw55bpdcgfz9j05xlzr0lvy5prkh0";
      };

      installPhase = ''
        mkdir -p $out/bin
        cp apk.static $out/bin
      '';

      meta = with stdenv.lib; {
        description = "Alpine Package Keeper - the package manager from Alpine Linux";
        homepage = "https://git.alpinelinux.org/cgit/apk-tools/";
        license = licenses.gpl2;
        platforms = platforms.linux;
      };
    }
