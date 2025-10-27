{ pkgs }:
let
    rev = "d02a1db4b43eabef292dfe2139999fa3d08fca09";
in
{
    version = rev;
    main = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/dividat/focus-shift/${rev}/index.js";
        hash = "sha256-6IE5EiGioogRhRKB1WGslYP9uPiWZxk+Gctmc4hmCLs=";
    };
}
