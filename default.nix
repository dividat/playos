let nixpkgs = (import ./nix/nixpkgs.nix).nixpkgs; in
let nixos = (import ./nix/nixpkgs.nix).nixos; in
let makeDiskImage = (import ./nix/nixpkgs.nix).makeDiskImage; in
with nixpkgs;
let
  configuration = (import ./system/configuration.nix) { inherit config pkgs lib; };
in
  makeDiskImage {
    inherit pkgs lib;
    config = (nixos { 
        inherit configuration; 
        system = "x86_64-linux";
      }).config;
    partitionTableType = "efi";
    diskSize = 2048;
  }
