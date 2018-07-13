{stdenv, fetchurl, gzip, proot, nixpkgs_musl}:
let
  # Compiled version of apk (linked with musl)
  apk-tools = ((import ./apk-tools)  nixpkgs_musl);

  # Static prebuilt version of apk
  apk-tools-static = (import ./apk-tools-static) {inherit stdenv fetchurl;};

  # apk2nix tool
  apk2nix = (import ./apk2nix) {inherit stdenv proot apk-tools-static;};
in 
  {
    inherit apk-tools apk-tools-static apk2nix;

    base-system = (import ./system-builder) {
      inherit stdenv apk-tools-static proot;
      name = "alpine-base-system";
      apks = map fetchurl (import ./pkgs/alpine-base.nix);
    };

  }
