{ stdenv
, proot
, systemBuilder
, alpine-sdk-pkgs}:
{ makedepends ? []
, apkbuild-dir
, name
, packager-private-key ? ./key.rsa
}:
let
  build-system = systemBuilder {
    name = "alpine-build-system";
    apks = alpine-sdk-pkgs ++ makedepends;
  };
in
stdenv.mkDerivation {
  name = "${name}.apk";
  src = ./.;

  buildInputs = [ proot ];

  phases = [ "unpackPhase" "configurePhase" "buildPhase" ];

  configurePhase = with stdenv.lib; ''
    export BUILD_SYSTEM=${build-system}
    export APKBUILD_DIR=${apkbuild-dir}

    # tools
    export PROOT=${proot}/bin/proot
  '';


}

