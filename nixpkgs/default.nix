# his pins the version of nixpkgs and helper to import from <nixpkgs/nixos>.
let
  # Bootstrap with currently available version of nixpkgs
  _nixpkgs = import <nixpkgs> {};

  nixpkgsRepo = _nixpkgs.fetchFromGitHub {
    owner = "NixOS"
    ; repo = "nixpkgs-channels"
    ; rev = "f52505fac8c82716872a616c501ad9eff188f97f"
    ; sha256 = "0q2m2qhyga9yq29yz90ywgjbn9hdahs7i8wwlq7b55rdbyiwa5dy";
  };

in
  { nixpkgs = import nixpkgsRepo
  ; importFromNixos = path: import (nixpkgsRepo + "/nixos/" + path);}
