{stdenv
, fetchurl
, binutils
# default environment that is compiled into barebox
, defaultEnv
}:
stdenv.mkDerivation rec {
  version = "2018.08.1";
  name = "barebox-${version}.efi";

  src = fetchurl {
    url = "https://www.barebox.org/download/barebox-${version}.tar.bz2";
    sha256 = "1ipld2p0na4bn8089xf5zspwadp0x6ipva9nhcjyhx9axv9q2yqb";
  };


  patches = [
    # scripts/genenv fails to remove read only files in temp directory. This
    # patch stops genenv from removing the temp directory and lets nix clean
    # up.
    ./fix-removal-of-temp-defaultenv.patch
  ];

  # Fix messed up shebangs
  postPatch = ''
    patchShebangs .
  '';

  configurePhase = ''
    export ARCH=x86
    make efi_defconfig

    ${if defaultEnv != null then
      ''
        substituteInPlace .config --replace 'CONFIG_DEFAULT_ENVIRONMENT_PATH=""' 'CONFIG_DEFAULT_ENVIRONMENT_PATH="${defaultEnv}"'
      ''
      else
      "" }
  '';

  hardeningDisable = [ "stackprotector" ];

  installPhase = ''
    cp barebox.efi $out

    ls -lR defaultenv/
    chmod -R +w defaultenv/
  '';

}
