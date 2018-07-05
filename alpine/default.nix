{stdenv, fetchurl, gzip, proot, nixpkgs_musl}:
let
  # Compiled version of apk (linked with musl)
  apk-tools = ((import ./apk-tools)  nixpkgs_musl);

  # Static prebuilt version of apk
  apk-tools-static = (import ./apk-tools-static) {inherit stdenv fetchurl;};

  # Helper to grab package from Alpine Linux repository
  fetchPkg = {
    pkg
  , version
  , sha256
  , repo ? "http://dl-cdn.alpinelinux.org/alpine/v3.7/main/x86_64"
  }:
  fetchurl {
    url = "${repo}/${pkg}-${version}.apk";
    inherit sha256;
  };

in 
  {
    inherit apk-tools apk-tools-static;

    base-system = (import ./system-builder) {
      inherit stdenv apk-tools-static proot;
      name = "alpine-base-system";
      apks = map fetchPkg (import ./base-system.nix);
    };

  }
