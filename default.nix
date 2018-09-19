let nixpkgs = (import ./nixpkgs).nixpkgs {
    overlays = [ (import ./pkgs) ];
}; 
in
let 
  importFromNixos = (import ./nixpkgs).importFromNixos;
  nixos = importFromNixos "";
  makeDiskImage = importFromNixos "lib/make-disk-image.nix"; 

  system = (import ./system) {
    inherit (nixpkgs) config pkgs lib;
    inherit nixos;
  };

in
with nixpkgs;
  makeDiskImage {
    inherit pkgs lib;
    config = system.config;
    partitionTableType = "efi";
    diskSize = 2048;
  }
