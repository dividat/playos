super:
let
    version = "1.42";
in
super.connman.overrideAttrs (old: {
    inherit version;
    src = super.fetchurl {
      url = "mirror://kernel/linux/network/connman/connman-${version}.tar.xz";
      hash = "sha256-o+a65G/Age8una48qk92Sd6JLD3mIsICg6wMqBQjwqo=";
    };
    patches = [
      ./create-libppp-compat.h.patch
      # Patches for CVEs, fixed in upstream ConnMan >=1.45
      (super.fetchpatch {
        name = "CVE-2025-32366.patch";
        url = "https://git.kernel.org/pub/scm/network/connman/connman.git/patch/?id=8d3be0285f1d4667bfe85dba555c663eb3d704b4";
        hash = "sha256-kPb4pZVWvnvTUcpc4wRc8x/pMUTXGIywj3w8IYKRTBs=";
      })
      (super.fetchpatch {
        name = "CVE-2025-32743.patch";
        url = "https://git.kernel.org/pub/scm/network/connman/connman.git/patch/?id=d90b911f6760959bdf1393c39fe8d1118315490f";
        hash = "sha256-odkjYC/iM6dTIJx2WM/KKotXdTtgv8NMFNJMzx5+YU4=";
      })
      # Custom patch to add a ipconfig method heuristic to ConnMan,
      # can be made to work up to ConnMan 1.45 at least. If not
      # accepted upstream, we may want to switch to another,
      # application-level approach for achieving the same effect.
      ./ipconfig-method-in-sorting.patch
    ];
})
