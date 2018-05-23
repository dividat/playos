{ stdenv, lib, fetchurl, libressl, zlib, lua, musl, pkgconfig, gcc, ... }:
    stdenv.mkDerivation rec {
      name = "apk-tools-${version}";
      version = "2.9.1";
      src = fetchurl {
        url = "https://git.alpinelinux.org/cgit/apk-tools/snapshot/apk-tools-${version}.tar.bz2";
        sha256 = "0vpi7y01njsrcgj559npjhq2g1w99i34rkp76apkhbzc5dnidz94";
      };

      buildInputs = [
        libressl
        zlib
        lua
        musl
        pkgconfig
      ];

      nativeBuildInputs = [ pkgconfig ];

      patches = [ 
        # Use $CC and $LD instead of hardcoded compilers and look for lua.pc instead of lua5.2.pc
        ./Makefiles.patch 
      ];

      installPhase = ''
        mkdir -p $out/bin
        cp src/apk $out/bin
        mkdir -p $out/lib
        cp src/apk.so $out/lib
      '';

      meta = with stdenv.lib; {
        description = "Alpine Package Keeper - the package manager from Alpine Linux";
        homepage = "https://git.alpinelinux.org/cgit/apk-tools/";
        license = licenses.gpl2;
        platforms = platforms.linux;
      };
    }
