{stdenv, fetchurl, gzip, proot, nixpkgs_musl}:
let
  # Compiled version of apk (linked with musl)
  apk-tools = ((import ./apk-tools)  nixpkgs_musl);

  # Static prebuilt version of apk
  apk-tools-static = (import ./apk-tools-static) {inherit stdenv fetchurl;};

  # apk2nix tool
  apk2nix = (import ./apk2nix) {inherit stdenv proot apk-tools-static;};

  # Build Alpine Linux systems
  systemBuilder = (import ./system-builder) {inherit stdenv apk-tools-static proot;};

  apkBuilder = (import ./apk-builder) { 
    inherit stdenv proot systemBuilder;
    alpine-sdk-pkgs = map fetchurl (import ./systems/alpine-sdk.nix);
  };

in 
  {
    inherit apk-tools apk-tools-static apk2nix systemBuilder apkBuilder;

    # TODO: system definitions here are not really needed and should be removed (all of them)
    base-system = systemBuilder {
      name = "alpine-base-system";
      apks = map fetchurl (import ./systems/alpine-base.nix);
    };

    bootable-system = systemBuilder {
      name = "alpine-bootable-system";
      apks = map fetchurl (import ./systems/bootable-system.nix);
    };

    sdk-system = systemBuilder {
      name = "alpine-sdk-system";
      apks = map fetchurl (import ./systems/alpine-sdk.nix);
    };

  }
