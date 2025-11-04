{ pkgs }:
let
    rev = "b475f7bb38ad0f7fbe157878b32b28273b55522e";
in
{
    version = rev;
    main = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/dividat/focus-shift/${rev}/index.js";
        hash = "sha256-WFeJHZBmyglYuazb574XNi5lFmwqjSsMHlYeBhzpom4=";
    };
}
