{stdenv
, rauc
, version
, cert
, key
, systemTarball}:
stdenv.mkDerivation {
  name = "bundle-${version}.raucb";

  buildInputs = [ rauc ];

  buildCommand = ''
    mkdir -p $TEMP/rauc-bundle

    cp --dereference ${systemTarball} $TEMP/rauc-bundle/system.tar.xz

    cat <<EOF > $TEMP/rauc-bundle/manifest.raucm
      [update]
      compatible=Dividat Play Computer
      version=${version}

      [image.system]
      filename=system.tar.xz
    EOF

    rauc \
      --cert ${cert} \
      --key ${key} \
      bundle \
      $TEMP/rauc-bundle/ \
      $out
  '';

}
