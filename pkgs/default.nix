# overlay for custom packages
self: super: {

  rauc = (import ./rauc) super;

  dividat-driver = (import ./dividat-driver) {
    inherit (super) stdenv fetchurl;
  };

}
