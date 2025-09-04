{ pkgs }:
let
    version = "1.0.0";
in
{
    inherit version;
    main = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/dividat/focus-shift/refs/tags/${version}/index.js";
        hash = "sha256-vFarWWG9waIyOKc9F+4McgFYxVcI+BkseaRgCbELBus=";
    };
}
