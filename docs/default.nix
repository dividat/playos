{ stdenv, makeFontsConf, pandoc, python3Packages, ibm-plex, version }:
let
  fontsConf = makeFontsConf {
    fontDirectories = [ ibm-plex ];
  };
in
stdenv.mkDerivation {
  name = "playos-docs-${version}";

  src = ./.;

  buildInputs =
    let
      # Workaround to allow setting custom fontconfig file.
      # Should be fixed in next version of Nixpkgs, so the regular package
      # can again be used (https://github.com/NixOS/nixpkgs/pull/254239).
      weasyprint = python3Packages.weasyprint.overrideAttrs (o: {
        makeWrapperArgs = [ "--set-default FONTCONFIG_FILE ${o.FONTCONFIG_FILE}" ];
      });
    in
    [ pandoc weasyprint ];

  installPhase = ''
    DATE=$(date -I)
    export FONTCONFIG_FILE="${fontsConf}"

    mkdir -p $out

    cd arch
    pandoc \
      --template ../templates/default.html \
      --toc --number-sections \
      -V version=${version} -M date=$DATE \
      -t html5 \
      --standalone --self-contained -o $out/arch.html \
      Readme.org
    weasyprint $out/arch.html $out/arch.pdf

    cd ../user-manual
    pandoc \
        --template ../templates/default.html \
        --toc --number-sections --toc-depth=2 \
        -V version=${version} -M date=$DATE \
        -t html5 \
        --standalone --self-contained -o $out/user-manual.html \
        Readme.org
    weasyprint $out/user-manual.html $out/user-manual.pdf
  '';
}
