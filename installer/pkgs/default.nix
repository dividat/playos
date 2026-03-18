let
  nixpkgs = builtins.fetchTarball {
    # nixos-24.05 2024-10-07
    url = "https://github.com/nixos/nixpkgs/archive/ecbc1ca8ffd6aea8372ad16be9ebbb39889e55b6.tar.gz";
    sha256 = "0yfaybsa30zx4bm900hgn3hz92javlf4d47ahdaxj9fai00ddc1x";
  };

  overlay =
    self: super: {
      rauc = (import ./rauc) super;

      nixos = import "${nixpkgs}/nixos";
    };
in
import nixpkgs {
  overlays = [ overlay ];
}
