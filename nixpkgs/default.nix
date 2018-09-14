# This pins the version of nixpkgs and helper to import from <nixpkgs/nixos>.
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
  { nixpkgs = import nixpkgsRepo
  ; importFromNixos = path: import (nixpkgsRepo + "/nixos/" + path);}
