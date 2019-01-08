# his pins the version of nixpkgs and helper to import from <nixpkgs/nixos>.
let
  # Bootstrap with currently available version of nixpkgs
  _nixpkgs = import <nixpkgs> {};

  nixpkgsRepo = _nixpkgs.fetchFromGitHub {
    owner = "NixOS"
    ; repo = "nixpkgs-channels"
    ; rev = "2dc559868c94a6aad7cacbebb0ba7abdd9e08d91"
    ; sha256 = "0hass2jk4jaijnsgvfk59kq5rli56bc7xv8gwsc9y6cff5sxfv8g";
  };

in
  { nixpkgs = import nixpkgsRepo
  ; importFromNixos = path: import (nixpkgsRepo + "/nixos/" + path);}
