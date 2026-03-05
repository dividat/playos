let
  nixpkgs = builtins.fetchTarball {
    # release-24.11 2025-02-10
    url = "https://github.com/NixOS/nixpkgs/archive/edd84e9bffdf1c0ceba05c0d868356f28a1eb7de.tar.gz";
    sha256 = "1gb61gahkq74hqiw8kbr9j0qwf2wlwnsvhb7z68zhm8wa27grqr0";
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
