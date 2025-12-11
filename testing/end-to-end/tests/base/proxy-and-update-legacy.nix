# Runs the same test as proxy-and-update, but in "legacy" mode that assumes
# problematic older PlayOS systems (2025.3.{0,1,2}), where mke2fs has not been
# configured to exclude unsupported ext4 features.
args@{pkgs, ...}:
pkgs.callPackage ./proxy-and-update.nix (args // { legacyMode = true; })
