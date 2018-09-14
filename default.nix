let nixpkgs = (import ./nixpkgs).nixpkgs {
    overlays = [ (import ./pkgs) ];
}; 
in
let importFromNixos = (import ./nixpkgs).importFromNixos; in
let nixos = importFromNixos ""; in
let makeDiskImage = importFromNixos "lib/make-disk-image.nix"; in
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
