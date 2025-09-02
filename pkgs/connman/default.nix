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
      # Custom patch to add a ipconfig method heuristic to ConnMan,
      # can be made to work up to ConnMan 1.45 at least. If not
      # accepted upstream, we may want to switch to another,
      # application-level approach for achieving the same effect.
      ./ipconfig-method-in-sorting.patch
    ];
})
