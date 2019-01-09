{ stdenv, pandoc
, version}:
stdenv.mkDerivation {
  name = "playos-docs-${version}";

  src = ./.;

  buildInputs = [ pandoc ];

  installPhase = ''
    DATE=$(date -I)

    mkdir -p $out

    cd arch
    pandoc \
      --template ../templates/default.html \
      --toc --number-sections \
      -V version=${version} -M date=$DATE \
      -t html5 \
      --standalone --self-contained -o $out/arch.html \
      Readme.org

    cd ../user-manual
    pandoc \
        --template ../templates/default.html \
        --toc --number-sections \
        -V version=${version} -M date=$DATE \
        -t html5 \
        --standalone --self-contained -o $out/user-manual.html \
        Readme.org
  '';
}
