self: super: {

  dt-utils = (import ../pkgs/dt-utils) {
    inherit (super) stdenv fetchgit autoreconfHook libudev pkgconfig;
  };

}
