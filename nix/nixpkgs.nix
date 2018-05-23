# This pins the version of nixpkgs
let
  _nixpkgs = import <nixpkgs> {};
in 
  import (_nixpkgs.fetchFromGitHub 
  { owner = "NixOS"
  ; repo = "nixpkgs"
  ; rev = "cc2ac8a39ebad753d8da6adf4c0d3dd18ec7fa65"
  ; sha256 = "1c0dxh44qfypgs4by40s8aaf2f62mmlvbvmjffv1g7npipmc6p1p"; })

