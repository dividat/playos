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
    ];
})
