# This pins the version of nixpkgs and imports stuff from <nixpkgs/nixos> conveniently.
let
  # Bootstrap with currently available version of nixpkgs
  _nixpkgs = import <nixpkgs> {};

  nixpkgsRepo = _nixpkgs.fetchFromGitHub { 
    owner = "NixOS"
    ; repo = "nixpkgs"
    ; rev = "03667476e330f91aefe717a3e36e56015d23f848"
    ; sha256 = "0cyhrvcgp8hppsvgycr0a0fiz00gcd24vxcxmv22g6dibdf5377h"; 
  };

in 
  { nixpkgs = (import nixpkgsRepo) { overlays = [ (import ./overlay.nix) ]; }
  ; nixos = import (nixpkgsRepo + "/nixos")
  ; makeDiskImage = import (nixpkgsRepo + "/nixos/lib/make-disk-image.nix");}
