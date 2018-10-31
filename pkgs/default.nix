# overlay for custom packages
self: super: {

  dt-utils = (import ../pkgs/dt-utils) {
    inherit (super) stdenv fetchgit autoreconfHook libudev pkgconfig;
  };

  rauc = (import ./rauc) super;

  dividat-driver = (import ./dividat-driver) {
    inherit (super) stdenv fetchurl;
  };

}
