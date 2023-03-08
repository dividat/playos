version: self: super: {

  dividat-driver = (import ./dividat-driver) {
    inherit (super) stdenv fetchFromGitHub buildGoModule;
    pkgs = self;
  };

  playos-kiosk-browser = import ../../kiosk {
    pkgs = self;
    system_name = "PlayOS";
    system_version = version;
  };

  breeze-contrast-cursor-theme = super.callPackage ./breeze-contrast-cursor-theme {};

}
