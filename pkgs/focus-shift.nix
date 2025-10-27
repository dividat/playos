{ pkgs }:
let
    rev = "1e43419e1562dbe10ab4ce2a768e0fd0d51148bb";
in
{
    version = rev;
    main = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/dividat/focus-shift/${rev}/index.js";
        hash = "sha256-dOGP2y5YV/+nB25hpBj04CL8yjYH7CIEg+QjfAirzDI=";
    };
}
