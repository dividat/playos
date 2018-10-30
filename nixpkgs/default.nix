# This pins the version of nixpkgs and helper to import from <nixpkgs/nixos>.
let
  # Bootstrap with currently available version of nixpkgs
  _nixpkgs = import <nixpkgs> {};

  nixpkgsRepo = _nixpkgs.fetchFromGitHub { 
    owner = "NixOS"
    ; repo = "nixpkgs"
    ; rev = "fa3ec9c8364eb2153d794b6a38cec2f8621d0afd"
    ; sha256 = "03c5q4mngbl8j87r7my53b261rmv1gpzp1vg1ql6s6gbjy9pbn92"; 
  };

in 
  { nixpkgs = import nixpkgsRepo
  ; importFromNixos = path: import (nixpkgsRepo + "/nixos/" + path);}
