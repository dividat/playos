# overlay for custom packages
self: super: {

  dt-utils = (import ../pkgs/dt-utils) {
    inherit (super) stdenv fetchgit autoreconfHook libudev pkgconfig;
  };

  rauc = (import ./rauc) {
    inherit (super) stdenv fetchurl glib curl json-glib pkgconfig;
  };

}
