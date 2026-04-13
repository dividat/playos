let
  nixpkgs = builtins.fetchTarball {
    # release-24.11 2025-02-10
    #
    # This matches the nixpkgs version used in PlayOS releases since 2025.3.1
    # (inclusive). All releases starting from 2025.3.1 will have the same
    # "skeleton" packages. The last release with different skeleton packages is
    # 2024.7.0 (nixos 23.11).
    #
    # Note that this cannot be set to an "ancient" version, because it leads to
    # hardware compatibility issues.
    #
    # There are two main reasons why this might need to be bumped:
    # - (future) hardware (in)compatibility
    # - additional software features needed for RAUC/GRUB/installer not
    #   available in earlier versions
    #
    # Bumping the version requires careful testing with both the current/next
    # PlayOS system and previous/current/next hardware.
    #
    # If at all possible, avoid bumping.
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
