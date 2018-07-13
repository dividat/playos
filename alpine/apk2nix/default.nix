{ stdenv, proot, apk-tools-static}:
stdenv.mkDerivation {
  name = "apk2nix";
  src = ./.;

  installPhase = ''
    mkdir -p $out/bin
    cp ./apk2nix $out/bin/apk2nix
  '';
}
