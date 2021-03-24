# Inspiration: https://nixos.wiki/wiki/FAQ/Pinning_Nixpkgs
{ src, patches }:

(import <nixpkgs> {}).runCommand "nixpkgs-${src.rev}"
  {
    inherit src;
    inherit patches;
  }
  ''
    cp -r $src $out
    chmod -R +w $out
    for p in $patches; do
      echo "Applying patch $p";
      patch -d $out -p1 < "$p";
    done
  ''
