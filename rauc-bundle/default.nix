{ stdenv, perl, pixz, pathsFromGraph
, importFromNixos
, rauc
, version, cert
, systemToplevel
}:

let

  testingKey = ../testing/pki/key.pem;

  systemTarball = (importFromNixos "lib/make-system-tarball.nix") {
    inherit stdenv perl pixz pathsFromGraph;

    fileName = "system";

    contents = [
      {
        source = systemToplevel + "/initrd";
        target = "/initrd";
      }
      {
        source = systemToplevel + "/kernel";
        target = "/kernel";
      }
      {
        source = systemToplevel + "/init" ;
        target = "/init";
      }
    ];

    storeContents = [{
        object = systemToplevel;
        symlink = "/run/current-system";
      }];
  } + "/tarball/system.tar.xz";
in
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
      --key ${testingKey} \
      bundle \
      $TEMP/rauc-bundle/ \
      $out
  '';

}
