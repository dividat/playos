let nixpkgs = (import ./nixpkgs.nix).nixpkgs {}; in
let nixos = (import ./nixpkgs.nix).nixos; in
let makeDiskImage = (import ./nixpkgs.nix).makeDiskImage; in
with nixpkgs;
let
  configuration = (import ./configuration.nix) { inherit config lib; };
in
  makeDiskImage {
    inherit pkgs lib;
    config = (nixos { inherit configuration; }).config;

    partitionTableType = "efi";
    diskSize = 2048;
  }
